#!/bin/bash

# Location of clouds.yaml file pointing to the OSP environment. This variable
# takes precedence above $PWD and user and system default locations.
# https://docs.openshift.com/container-platform/4.5/installing/installing_openstack/installing-openstack-installer-custom.html#installation-osp-describing-cloud-parameters_installing-openstack-installer-custom
export OS_CLIENT_CONFIG_FILE=~/psi/clouds.yaml

# openshift-install stuff configuration stuff used by almost all of the
# scripts.
CLUSTER_NAME=ocs.mkarnik.com
CLUSTER_DIR=~/psi/"$CLUSTER_NAME"
INSTALL_CONFIG=~/psi/install-config.yaml.ocs-node
TF_VARS_FILE="$CLUSTER_DIR/terraform.tfvars.json"
CLUSTER_ID_FILE="$CLUSTER_DIR/cluster.id"

# FLOATING_IP is associated to the *.apps.$CLUSTER_NAME endpoint for public
# connectivity by the set_ingress_ip script.
FLOATING_IP="10.0.109.242"

# Custom NTP servers are required in various lab environments.
# If this isn't required in your environment, comment the NTP_SERVERS
# declaration out and the installation script will skip over the
# ignition configuration required to implement this configuration.
NTP_SERVERS=( clock.redhat.com clock2.redhat.com )

# The following are used to update the cluster's pull secrets to pull from
# other private registries such as from the rhceph-dev registry. These are used
# by the update_pull_secret script.
UPDATE_PULL_SECRET=true

# SECRETS_FILE is downloaded from the openshift cluster automatically.
SECRETS_FILE="$CLUSTER_DIR/secrets.json"
# AUTHS_FILE has to be created manually by combining all the custom pull
# secrets that you want to provide to the OCP cluster. This file is merged into
# SECRETS_FILE.
# The format is:
#{
#  "auths": {
#    "<AUTH_PROVIDER>": {
#      "auth": "<AUTH_TOKEN>",
#      "email": "<AUTH_EMAIL>"
#    },
#    "<AUTH_PROVIDER_2>": {
#      "auth": "<AUTH_TOKEN_2>",
#      "email": "<AUTH_EMAIL_2>"
#    }
#  }
#}

AUTHS_FILE=~/ocs/rhceph-dev_auths.json

