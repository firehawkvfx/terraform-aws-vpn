#!/bin/bash

EXECDIR="$(pwd)"
SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )" # The directory of this script
cd $SCRIPTDIR

export AWS_DEFAULT_REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone | sed 's/\(.*\)[a-z]/\1/')

manifest="$SCRIPTDIR/base-ami/manifest.json"
if [[ -f "$manifest" ]]; then
    export PKR_VAR_openvpn_server_base_ami="$(jq -r '.builds[] | select(.name == "openvpn-server-base-ami") | .artifact_id' "$manifest" | tail -1 | cut -d ":" -f2)"
    echo "Found openvpn_server_base_ami in manifest: PKR_VAR_openvpn_server_base_ami=$PKR_VAR_openvpn_server_base_ami"
fi

# Packer Vars
export PKR_VAR_aws_region="$AWS_DEFAULT_REGION"

export PACKER_LOG=1
export PACKER_LOG_PATH="$SCRIPTDIR/packerlog.log"

export PKR_VAR_vpc_id="$(cd ../../../vpc; terraform output -json "vpc_id" | jq -r '.')"
echo "Using VPC: $PKR_VAR_vpc_id"
export PKR_VAR_subnet_id="$(cd ../../../vpc; terraform output -json "public_subnets" | jq -r '.[0]')"
echo "Using Subnet: $PKR_VAR_subnet_id"
export PKR_VAR_security_group_id="$(cd ../../../vpc; terraform output -json "consul_client_security_group" | jq -r '.')"
echo "Using Security Group: $PKR_VAR_security_group_id"

export PKR_VAR_manifest_path="$SCRIPTDIR/manifest.json"

mkdir -p $SCRIPTDIR/tmp/log
mkdir -p $SCRIPTDIR/ansible/collections/ansible_collections
rm -f $PKR_VAR_manifest_path
packer build "$@" $SCRIPTDIR/openvpn-server.pkr.hcl
cd $EXECDIR