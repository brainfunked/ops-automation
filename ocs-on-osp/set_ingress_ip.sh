#!/bin/bash

set -e

SCRIPT_DIR=$(dirname $(readlink -f $0))
VARS_SRC="$SCRIPT_DIR/vars.sh"

source "$VARS_SRC"

echo "## Floating IP: $FLOATING_IP"

if ! [[ -f $TF_VARS_FILE ]]
then
  echo "Unable to read terraform vars file: $TF_VARS_FILE"
  exit 1
fi

CLUSTER_ID=$(jq ."cluster_id" <"$TF_VARS_FILE" -M | sed 's/"//g')
echo "## Cluster ID: $CLUSTER_ID"
INGRESS_PORT="${CLUSTER_ID}-ingress-port"
echo "## Ingress Port: $INGRESS_PORT"

openstack floating ip set --port "$INGRESS_PORT" "$FLOATING_IP"

ping_console() {
  echo -n "## Checking if console is reachable on the floating IP.."
  ping -c 1 console-openshift-console.apps.ocs.mkarnik.com &> /dev/null
  PING_SUCCESS=$?
  if ! [[ $PING_SUCCESS == 0 ]]
  then
    echo " retrying."
  fi

  return $PING_SUCCESS
}

while ! ping_console
do
  ping_console
done

echo " done!"

