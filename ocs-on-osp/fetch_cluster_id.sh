#!/bin/bash

set -e

TF_DIR=~/psi/latest
TF_VARS_FILE="$TF_DIR/terraform.tfvars.json"
CLUSTER_ID_FILE="$TF_DIR/cluster.id"

if ! [[ -f $TF_VARS_FILE ]]
then
  echo "Unable to read terraform vars file: $TF_VARS_FILE"
  exit 1
fi

CLUSTER_ID=$(jq ."cluster_id" <"$TF_VARS_FILE" -M | sed 's/"//g')
echo "$CLUSTER_ID" > "$CLUSTER_ID_FILE"

echo "## Cluster ID: $CLUSTER_ID"

