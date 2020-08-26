#!/bin/bash

set -e

SCRIPT_DIR=$(dirname $(readlink -f $0))
VARS_SRC="$SCRIPT_DIR/vars.sh"

source "$VARS_SRC"

if ! [[ -f $AUTHS_FILE ]]
then
  echo "Unable to read terraform vars file: $AUTHS_FILE"
  exit 1
fi

if ! [[ -f $TF_VARS_FILE ]]
then
  echo "Unable to read terraform vars file: $TF_VARS_FILE"
  exit 1
fi

CLUSTER_ID=$(jq ."cluster_id" <"$TF_VARS_FILE" -M | sed 's/"//g')
PULL_SECRET_OUTPUT="${CLUSTER_DIR}/pull-secret_${CLUSTER_ID}.json"

echo "## Cluster ID: $CLUSTER_ID"
echo "## Pull secret output file: $PULL_SECRET_OUTPUT"

if [[ -s $PULL_SECRET_OUTPUT && $(jq 'has("auths")' <"$PULL_SECRET_OUTPUT") == true ]]
then
  echo "- ${PULL_SECRET_OUTPUT} exists and contains .auths object."
  echo "- Not updating pull secret."
else
  echo "- ${PULL_SECRET_OUTPUT} either doesn't exist or contain .auths object."
  if [[ $(jq 'has("auths")' <$AUTHS_FILE) == true ]]
  then
    echo "- '$AUTHS_FILE' contains .auths object."
    echo "- Fetching existing pull secrets.."
    oc get -n openshift-config secret/pull-secret -ojson | jq -r '.data.".dockerconfigjson"' | base64 -d | jq . -M > "$SECRETS_FILE"
    echo "- Merging '${AUTHS_FILE}' into '${SECRETS_FILE}'.."
    jq -s '.[0] * .[1]' "$SECRETS_FILE" "$AUTHS_FILE" -M > "$PULL_SECRET_OUTPUT"
    echo "- Updating pull-secret on the cluster.."
    oc set data secret/pull-secret -n openshift-config --from-file=.dockerconfigjson="$PULL_SECRET_OUTPUT"
    echo "- Done."
  fi
fi
