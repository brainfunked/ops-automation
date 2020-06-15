#!/bin/bash

# Run this script after starting the creation of a cluster from OSD dashboard.
# This script assumes that there is only one cluster and explicitly works only
# on the first cluster output from `ocm cluster list`.

# Ensure that ocm and oc are in $PATH. The script clones
# https://github.com/JohnStrunk/ocp-rook-ceph into a subdirectory (if it isn't
# already), and updates it to the latest version before running the deployment
# script from that directory.

echo "### Checking for required tools in \$PATH.."
echo

if ! which ocm oc git
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

