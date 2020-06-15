#!/bin/bash

# Run this script after starting the creation of a cluster from OSD dashboard.
# This script assumes that there is only one cluster and explicitly works only
# on the first cluster output from `ocm cluster list`.

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

show_spinner()
{
  seconds=600 # 10 minutes wait for cluster nodes to reboot
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
  echo "Please ensure that ocm, oc and git are all available in \$PATH."
  exit 1
fi

echo
echo "### Checking if ocm is logged in.."
echo

if ! ocm whoami
then
  echo "Please ensure that ocm is logged in."
  exit 2
fi

echo
echo "### Gathering the first cluster's name and id.."
echo

read -r OSD_CLUSTER_ID OSD_CLUSTER_NAME OSD_CLUSTER_STATE <<<$(ocm cluster list --columns id,name,state | tail -n +2 | tail -n 1)

if [[ -z $OSD_CLUSTER_ID ]]
then
  echo "No cluster found."
  exit 3
fi

echo "$OSD_CLUSTER_ID" > cluster_id
echo "$OSD_CLUSTER_NAME" > cluster_name

echo "ID: $OSD_CLUSTER_ID, NAME: $OSD_CLUSTER_NAME"

echo
echo "### Checking (and waiting) for the cluster to be ready.."
echo

if [[ $OSD_CLUSTER_STATE != ready ]]
then
  while [[ $OSD_CLUSTER_STATE == installing ]]
  do
    OSD_CLUSTER_STATE=$(ocm cluster status $OSD_CLUSTER_ID | awk '$1 == "State:" { print $2 }')
    sleep 10
    echo "$(date +'%k:%M'): Waiting for the cluster to finish installing"
  done

  echo "Cluster $OSD_CLUSTER_NAME is not ready (state: $OSD_CLUSTER_STATE)"
  exit 4
else
  echo "Cluster $OSD_CLUSTER_NAME is ready!"
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

echo
echo "### Updating the cluster pull secret if applicable.."
echo

if [[ -s auths.json ]]
then
  echo "auths.json file exists, checking for .auths.."
  if [[ $(jq 'has("auths")' <auths.json) == true ]]
  then
    echo "- auths.json contains .auths."
    echo "- Pulling existing pull secrets.."
    oc get -n openshift-config secret/pull-secret -ojson | jq -r '.data.".dockerconfigjson"' | base64 -d | jq > secret.json
    echo "- Merging auths.json into secret.json.."
    jq -s '.[0] * .[1]' secret.json auths.json > pull-secret.json
    echo "- Updating pull-secret on the cluster.."
    oc set data secret/pull-secret -n openshift-config --from-file=.dockerconfigjson=pull-secret.json
    echo
    echo -n "- Waiting 10 minutes for the cluster to propagate the pull secret.. "
    show_spinner
    echo "done!"
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

