#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail

if ! [ -d state/ ]; then
  exit "No State, exiting"
  exit 1
fi

source ./state/env.sh
AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID:?"Missing env"}
AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY:?"Missing env"}
AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION:?"Missing env"}
CONCOURSE_USERNAME=${CONCOURSE_USERNAME:?"Missing env"}
CONCOURSE_PASSWORD=${CONCOURSE_PASSWORD:?"Missing env"}
CONCOURSE_DB_NAME=${CONCOURSE_DB_NAME:?"Missing env"}
CONCOURSE_DB_ROLE=${CONCOURSE_DB_ROLE:?"Missing env"}
CONCOURSE_DB_PASSWORD=${CONCOURSE_DB_PASSWORD:?"Missing env"}
VM_KEYPAIR_NAME=${VM_KEYPAIR_NAME:?"Missing env"}
DOMAIN=${DOMAIN:?"Missing env"}
CONCOURSE_BOSH_ENV=${CONCOURSE_BOSH_ENV:?"Missing env"}
CONCOURSE_DEPLOYMENT_NAME=${CONCOURSE_DEPLOYMENT_NAME:?"Missing env"}
set -x

bbl_cmd="bbl --state-dir state/"

PATH=$PATH:$(pwd)/bin

export AWS_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY
export AWS_DEFAULT_REGION

if [ -f state/bbl-state.json ] && bosh deployments -e $CONCOURSE_BOSH_ENV | grep $CONCOURSE_DEPLOYMENT_NAME; then
  bosh delete-deployment $CONCOURSE_DEPLOYMENT_NAME;
fi

if [ -f state/concourse-creds.yml ]; then
  rm -f state/concourse-creds.yml
fi

if [ -f state/bbl-state.json ] && $bbl_cmd lbs; then
  $bbl_cmd delete-lbs
fi

if [ -f state/rsakey.pem ]; then
  rm -f state/$DOMAIN.crt
  rm -f state/rsakey.pem
fi

if [ -f state/bbl-state.json ]; then
  $bbl_cmd destroy --no-confirm
fi

if aws ec2 describe-key-pairs | grep -q $VM_KEYPAIR_NAME; then
  aws ec2 delete-key-pair --key-name $VM_KEYPAIR_NAME
fi

