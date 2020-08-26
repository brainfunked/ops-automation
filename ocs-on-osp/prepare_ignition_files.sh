#!/bin/bash

SCRIPT_DIR=$(dirname $(readlink -f $0))
VARS_SRC="$SCRIPT_DIR/vars.sh"

source "$VARS_SRC"

# This script is pointless if no NTP servers are defined.
if [[ ${#NTP_SERVERS[@]} -lt 1 ]]
then
  echo "No NTP_SERVERS specified. Exiting."
  exit 1
fi

CHRONY_CONF_FILE="$SCRIPT_DIR/chrony.conf"

(
  for ntp_server in "${NTP_SERVERS[@]}"
  do
    echo "pool $ntp_server iburst"
  done
) > "$CHRONY_CONF_FILE"

# Generate chrony.conf
cat >> "$CHRONY_CONF_FILE" <<_CHRONY_
driftfile /var/lib/chrony/drift
makestep 1.0 3
rtcsync
logdir /var/log/chrony
_CHRONY_

# Generate json object with base64 string for the chrony configuration
CHRONY_CONF_STR="data:text/plain;charset=utf-8;base64,$(base64 -w0 <$CHRONY_CONF_FILE)"

CHRONY_CONF_IGN_FILE="$SCRIPT_DIR/chrony.conf_ign.json"
cat > "$CHRONY_CONF_IGN_FILE" <<_JSON_
{
  "filesystem": "root",
  "path": "/etc/chrony.conf",
  "user": {
    "name": "root"
  },
  "append": false,
  "contents": {
    "source": "$CHRONY_CONF_STR",
    "verification": {}
  },
  "mode": 420
}
_JSON_

#jq .contents.source "$CHRONY_CONF_IGN_FILE" | sed -r 's/"//g;s/^.+base64,//' | base64 -d

exit

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
