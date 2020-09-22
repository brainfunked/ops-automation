#!/bin/bash

# Run this script after starting the creation of a cluster from OSD dashboard.
# This script assumes that there is only one cluster and explicitly works only
# on the last (presumably the latest) cluster output from `ocm list clusters`.
# The cluster name is expected to contain the username output from `ocm whoami`
# in full.

# The script is largely idempotent. Steps already completed should be skipped.
# If the script fails before completion due to timeouts and such, just run it
# again and it should resume.
#
# IMPORTANT: If the OCS_AUTHS_JSON environment variable is defined;
# pointing to an exiting auths.json file that contains the .auths
# object; it is merged with the cluster's existing pull secret. This
# step is skipped if the environment variable is not defined or if
# file is not available. Use the following template or modify the
# auths.json.template and point the environment variable to it:
#
# {
#   "auths": {
#     "<AUTH_PROVIDER>": {
#       "auth": "<AUTH_TOKEN>",
#       "email": "<AUTH_EMAIL>"
#     }
#   }
# }

set -e

# Absolute path to this script's directory.
SCRIPT_DIR="$(dirname $(readlink -f $0))"

# Load configuration. This assumes that it is collocated with this script.
source "$SCRIPT_DIR/deploy_ocs_on_osd.conf"

if ! [[ -n $OSD_PROJECT_DIR && -d $OSD_PROJECT_DIR ]]
then
  echo "=== [ERROR] OSD_PROJECT_DIR environment variable must be defined and the directory must exist."
  exit 254
else
  echo "=== Using '$OSD_PROJECT_DIR' as the project directory."
  echo
fi

usage()
{
  cat <<_END_
deploy-ocs-on-osd.sh <OP>

Possible OPs:
--details-only: Write cluster details in files and quit. Any other options are ignored.
--prepare: (Default) Run the whole script to prepare the cluster for OCS deployment.
_END_
}

while [[ ${1:+defined} ]]
do
  case "$1" in
    "--details-only")
      DETAILS_ONLY="true"
      echo "=== Only fetching the details."
      echo
      ;;
    "--prepare")
      PREPARE_CLUSTER="true"
      echo "=== Preparing the cluster for OCS deployment."
      echo
      ;;
    *)
      usage
      exit 255
      ;;
  esac
  shift
done

if ! [[ $DETAILS_ONLY == true || $PREPARE_CLUSTER == true ]]
then
  usage
  exit 255
fi

# Shows spinner for and sleeps for specified number of seconds, 10 otherwise
show_spinner_and_sleep()
{
  seconds=${1:-10}
  i=1
  sp="/-\|"
  echo -n ' '
  while [[ $seconds -gt 0 ]]
  do
    printf "\b${sp:i++%${#sp}:1}"
    let seconds--
    sleep 1
  done
  printf "\b"
}

echo "### Checking for required tools in \$PATH.."
echo

if ! which ocm oc git jq
then
  echo "- [ERROR] Please ensure that ocm, oc and git are all available in \$PATH."
  exit 1
fi

echo
echo "### Checking if ocm is logged in.."
echo

if ! ocm whoami
then
  echo "- [ERROR] Please ensure that ocm is logged in."
  exit 2
fi

echo
echo "### Gathering the last cluster's name and id.."
echo

OCM_USER=$(ocm whoami | jq .username -r -M)

echo "Using the latest cluster matching username '$OCM_USER'."

read -r CURRENT_CLUSTER_ID CURRENT_CLUSTER_NAME CURRENT_CLUSTER_STATE <<<$(\
  ocm list cluster \
    --columns id,name,state \
    --parameter search="name like '%${OCM_USER}%'" \
  | tail -n +2 | tail -n 1\
)

if [[ -z $CURRENT_CLUSTER_ID ]]
then
  echo "- [ERROR] No cluster found."
  exit 3
fi

echo "$CURRENT_CLUSTER_ID" > "$OSD_PROJECT_DIR/cluster_id"
echo "$CURRENT_CLUSTER_NAME" > "$OSD_PROJECT_DIR/cluster_name"

echo "ID: $CURRENT_CLUSTER_ID"
echo "NAME: $CURRENT_CLUSTER_NAME"

echo
echo "### Checking (and waiting) for the cluster to be ready.."
echo

if [[ $CURRENT_CLUSTER_STATE != ready ]]
then
  # Check for the state to be "installing"
  echo "- Cluster is not ready. Checking for ongoing installation.."
  while
    CURRENT_CLUSTER_STATE=$(ocm cluster status $CURRENT_CLUSTER_ID | awk '$1 == "State:" { print $2 }')
    if [[ $CURRENT_CLUSTER_STATE != installing ]]
    then
      break
    fi
    echo -n "- $(date +'%k:%M'): Waiting for the cluster to finish installing.. "
    show_spinner_and_sleep 60
  do
    echo
  done
  echo "done!"

  # Once installation is finished, check that the cluster is actually ready
  if [[ $CURRENT_CLUSTER_STATE != ready ]]
  then
    echo "- [ERROR] Cluster $CURRENT_CLUSTER_NAME state: $CURRENT_CLUSTER_STATE."
    exit 4
  fi
else
  echo "- Cluster $CURRENT_CLUSTER_NAME is ready!"
fi

echo
echo "### Storing cluster's access credentials.."
echo

CLUSTER_DIR="$OSD_PROJECT_DIR/$CURRENT_CLUSTER_ID"
CLUSTER_AUTH_DIR="$CLUSTER_DIR/auth"
CLUSTER_KUBECONFIG="$CLUSTER_AUTH_DIR/kubeconfig"
CLUSTER_KUBEADMIN="$CLUSTER_AUTH_DIR/kubeadmin-password"

echo "- Creating the cluster directory."
mkdir -pv "$CLUSTER_AUTH_DIR" "$CLUSTER_DIR/logs"

OSD_API_CREDENTIALS_ENDPOINT="/api/clusters_mgmt/v1/clusters/$CURRENT_CLUSTER_ID/credentials"
ocm get "$OSD_API_CREDENTIALS_ENDPOINT" | jq -r .kubeconfig > "$CLUSTER_KUBECONFIG"
echo "- kubeconfig: $CLUSTER_KUBECONFIG"
ocm get "$OSD_API_CREDENTIALS_ENDPOINT" | jq -r .admin.password > "$CLUSTER_KUBEADMIN"
echo "- kubeadmin credentials: $CLUSTER_KUBEADMIN"

CLUSTER_SYMLINK="$OSD_PROJECT_DIR/latest"

echo "- Setting up the latest symlink at '$CLUSTER_SYMLINK'."
if [[ -L $CLUSTER_SYMLINK ]]
then
  echo "- '$CLUSTER_SYMLINK' exists and is a symlink. Deleting it."
  rm -v "$CLUSTER_SYMLINK"
fi

if ! [[ -e $CLUSTER_SYMLINK ]]
then
  echo "- '$CLUSTER_SYMLINK' doesn't exist. Creating it."
  pushd "$OSD_PROJECT_DIR"
  ln -sv "$CURRENT_CLUSTER_ID" latest
  popd
else
  echo "- '$CLUSTER_SYMLINK' exists and is not a symlink. Skipping."
fi

export KUBECONFIG="$CLUSTER_KUBECONFIG"

echo
echo "### Checking authentication.."
echo

oc status

if [[ $DETAILS_ONLY == true ]]
then
  echo
  echo "### --details-only specified. Stopping."
  exit 254
fi

echo
echo "### Updating the cluster pull secret if applicable.."
echo

CLUSTER_PULL_SECRET_OUTPUT="$CLUSTER_DIR/pull-secret.json"
CLUSTER_SECRETS_JSON="$CLUSTER_AUTH_DIR/secret.json"

if [[ -n $OCS_AUTHS_JSON && -s $OCS_AUTHS_JSON ]]
then
  echo "- auths.json file exists at $OCS_AUTHS_JSON, checking for existing pull-secret json file."
  if [[ -s $CLUSTER_PULL_SECRET_OUTPUT && $(jq 'has("auths")' <"$CLUSTER_PULL_SECRET_OUTPUT") == true ]]
  then
    echo "- ${CLUSTER_PULL_SECRET_OUTPUT} exists and contains .auths object."
    echo "- Not updating pull secret."
  else
    echo "- ${CLUSTER_PULL_SECRET_OUTPUT} either doesn't exist or contain .auths object."
    if [[ $(jq 'has("auths")' <$OCS_AUTHS_JSON) == true ]]
    then
      echo "- auths.json contains .auths object."
      echo "- Fetching existing pull secrets.."
      oc get -n openshift-config secret/pull-secret -ojson | jq -r '.data.".dockerconfigjson"' | base64 -d | jq > "$CLUSTER_SECRETS_JSON"
      echo "- Merging auths.json into secret.json.."
      jq -s '.[0] * .[1]' $CLUSTER_SECRETS_JSON $OCS_AUTHS_JSON > "$CLUSTER_PULL_SECRET_OUTPUT"
      echo "- Updating pull-secret on the cluster.."
      oc set data secret/pull-secret -n openshift-config --from-file=.dockerconfigjson="$CLUSTER_PULL_SECRET_OUTPUT"
      echo
      echo "=== It may take around 20 minutes for the cluster to propagate the pull secret."
      echo
    fi
  fi
else
  echo "- auths.json file doesn't exist; not updating the pull secret."
fi

echo
echo "### OCS can now be deployed as an addon."
echo

ENVRC_FILE="$SCRIPT_DIR/envrc"
if [[ -s $ENVRC_FILE ]]
then
  echo "- Sourcing the $ENVRC_FILE to setup the environment."
  source "$ENVRC_FILE"
  echo
  echo "=== Done."
  echo
  echo
fi

