#!/bin/bash

set -e

SCRIPT_DIR=$(dirname $(readlink -f $0))
VARS_SRC="$SCRIPT_DIR/vars.sh"

source "$VARS_SRC"

if ! [[ -f $TF_VARS_FILE ]]
then
  echo "Unable to read terraform vars file: $TF_VARS_FILE"
  exit 1
fi

CLUSTER_ID=$(jq ."cluster_id" <"$TF_VARS_FILE" -M | sed 's/"//g')
echo "$CLUSTER_ID" > "$CLUSTER_ID_FILE"

echo "## Cluster ID: $CLUSTER_ID"

