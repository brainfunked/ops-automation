#!/bin/bash

SCRIPT_DIR=$(dirname $(readlink -f $0))
VARS_SRC="$SCRIPT_DIR/vars.sh"

source "$VARS_SRC"

mkdir -pv "$CLUSTER_DIR"

cp -v ~/psi/install-config.yaml.ocs-node ~/psi/latest/install-config.yaml

pushd ~/psi
openshift-install --dir=latest/ create ignition-configs

for i in "$CLUSTER_DIR"/{bootstrap,master,worker}.ign
do
  bkup_file="${i}.bak"
  mv -v "$i" "$bkup_file"
  jq < "$bkup_file" . -M > "$i"
done
popd

echo "# Now modify the ignition files to add chrony configuration."
