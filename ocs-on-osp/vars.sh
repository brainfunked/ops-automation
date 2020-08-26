#!/bin/bash

TF_DIR=~/psi/latest
TF_VARS_FILE="$TF_DIR/terraform.tfvars.json"
CLUSTER_ID_FILE="$TF_DIR/cluster.id"

NTP_SERVERS=( clock.redhat.com clock2.redhat.com )

CLUSTER_NAME=ocs.mkarnik.com
CLUSTER_DIR=~/psi/"$CLUSTER_NAME"

FLOATING_IP="10.0.109.242"

SECRETS_FILE=~/ocs/secret.json
AUTHS_FILE=~/ocs/rhceph-dev_auths.json

