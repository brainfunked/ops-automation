#!/bin/bash

CLUSTER_NAME=ocs.mkarnik.com
CLUSTER_DIR=~/psi/"$CLUSTER_NAME"

TF_VARS_FILE="$CLUSTER_DIR/terraform.tfvars.json"
CLUSTER_ID_FILE="$CLUSTER_DIR/cluster.id"

# Custom NTP servers are required in various lab environments.
# If this isn't required in your environment, comment the NTP_SERVERS
# declaration out and the corresponding script will fail with exit
# status 255.
NTP_SERVERS=( clock.redhat.com clock2.redhat.com )

FLOATING_IP="10.0.109.242"

INSTALL_CONFIG=~/psi/install-config.yaml.ocs-node
SECRETS_FILE=~/ocs/secret.json
AUTHS_FILE=~/ocs/rhceph-dev_auths.json

