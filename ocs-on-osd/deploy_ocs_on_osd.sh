#!/bin/bash

# Run this script after starting the creation of a cluster from OSD dashboard.
# This script assumes that there is only one cluster and explicitly works only
# on the first cluster output from `ocm cluster list`.

# The script is largely idempotent. Steps already completed should be skipped.
# If the script fails before completion due to timeouts and such, just run it
# again and it should resume.

# Ensure that ocm and oc are in $PATH. The script clones
# https://github.com/JohnStrunk/ocp-rook-ceph into a subdirectory (if it isn't
# already), and updates it to the latest version before running the deployment
# script from that directory.

# IMPORTANT: If auths.json file exists, it is merged with the cluster's
# existing pull secret. This step is skipped if the file is not available. Put
# any custom authentication tokens in a valid json file called auths.json with
# the following template (use auths.json.template):
# {
#   "auths": {
#     "<AUTH_PROVIDER>": {
#       "auth": "<AUTH_TOKEN>",
#       "email": "<AUTH_EMAIL>"
#     }
#   }
# }

set -e

usage()
{
  echo "--details-only: Write cluster details in files and quit."
}

while [[ ${1:+defined} ]]
do
  case "$1" in
    "--details-only")
      DETAILS_ONLY="true"
      ;;
    *)
      usage
      ;;
  esac
  shift
done

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
echo "### Gathering the first cluster's name and id.."
echo

read -r OSD_CLUSTER_ID OSD_CLUSTER_NAME OSD_CLUSTER_STATE <<<$(ocm cluster list --columns id,name,state | tail -n +2 | tail -n 1)

if [[ -z $OSD_CLUSTER_ID ]]
then
  echo "- [ERROR] No cluster found."
  exit 3
fi

echo "$OSD_CLUSTER_ID" > cluster_id
echo "$OSD_CLUSTER_NAME" > cluster_name

echo "ID: $OSD_CLUSTER_ID"
echo "NAME: $OSD_CLUSTER_NAME"

echo
echo "### Checking (and waiting) for the cluster to be ready.."
echo

if [[ $OSD_CLUSTER_STATE != ready ]]
then
  # Check for the state to be "installing"
  echo "- Cluster is not ready. Checking for ongoing installation.."
  while
    OSD_CLUSTER_STATE=$(ocm cluster status $OSD_CLUSTER_ID | awk '$1 == "State:" { print $2 }')
    if [[ $OSD_CLUSTER_STATE != installing ]]
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
  if [[ $OSD_CLUSTER_STATE != ready ]]
  then
    echo "- [ERROR] Cluster $OSD_CLUSTER_NAME state: $OSD_CLUSTER_STATE."
    exit 4
  fi
else
  echo "- Cluster $OSD_CLUSTER_NAME is ready!"
fi

echo
echo "### Storing cluster's access credentials.."
echo

OSD_API_CREDENTIALS_ENDPOINT="/api/clusters_mgmt/v1/clusters/$OSD_CLUSTER_ID/credentials"
ocm get "$OSD_API_CREDENTIALS_ENDPOINT" | jq -r .kubeconfig > kubeconfig
echo "- kubeconfig: $PWD/kubeconfig"
ocm get "$OSD_API_CREDENTIALS_ENDPOINT" | jq -r .admin > admin
echo "- kubeadmin credentials: $PWD/admin"

export KUBECONFIG="$PWD/kubeconfig"

echo
echo "### Checking authentication.."
echo

oc status

if [[ $DETAILS_ONLY == true ]]
then
  echo
  echo "### --details-only specified. Stopping."
  exit
fi

echo
echo "### Updating the cluster pull secret if applicable.."
echo

if [[ -s auths.json ]]
then
  echo "- auths.json file exists, checking for existing pull-secret json file."
  PULL_SECRET_OUTPUT="pull-secret_${OSD_CLUSTER_ID}.json"
  if [[ -s $PULL_SECRET_OUTPUT && $(jq 'has("auths")' <"$PULL_SECRET_OUTPUT") == true ]]
  then
    echo "- ${PULL_SECRET_OUTPUT} exists and contains .auths object."
    echo "- Not updating pull secret."
  else
    echo "- ${PULL_SECRET_OUTPUT} either doesn't exist or contain .auths object."
    if [[ $(jq 'has("auths")' <auths.json) == true ]]
    then
      echo "- auths.json contains .auths object."
      echo "- Fetching existing pull secrets.."
      oc get -n openshift-config secret/pull-secret -ojson | jq -r '.data.".dockerconfigjson"' | base64 -d | jq > secret.json
      echo "- Merging auths.json into secret.json.."
      jq -s '.[0] * .[1]' secret.json auths.json > "$PULL_SECRET_OUTPUT"
      echo "- Updating pull-secret on the cluster.."
      oc set data secret/pull-secret -n openshift-config --from-file=.dockerconfigjson="$PULL_SECRET_OUTPUT"
      echo
      echo -n "- Waiting 20 minutes for the cluster to propagate the pull secret.. "
      show_spinner_and_sleep 1200
      echo "done!"
    fi
  fi
else
  echo "- auths.json file doesn't exist; not updating the pull secret."
fi

echo
echo "### Installing community operators.."
echo

oc apply -f 'https://raw.githubusercontent.com/JohnStrunk/ocp-rook-ceph/master/community-operators.yaml'
echo
echo "- Waiting for community-operators deployment to be available."
oc wait deployment/community-operators -n openshift-marketplace --for condition=available
echo "- Community operators installed."

echo
echo "### Labeling nodes for OCS.."
echo

oc label no -lnode-role.kubernetes.io/worker cluster.ocs.openshift.io/openshift-storage=""

