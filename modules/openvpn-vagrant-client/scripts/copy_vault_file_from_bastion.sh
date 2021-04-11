#!/bin/bash
# This script aquires needed vpn client files from vault to an intermediary bastion

set -e

EXECDIR="$(pwd)"
SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )" # The directory of this script
cd "$SCRIPTDIR"

if [[ -z "$1" ]]; then
  echo "Error: 1st resourcetier must be provided. eg: dev / main / green / blue"
  echo "./copy_vault_file_from_bastion.sh main centos@ec2-3-25-143-13.ap-southeast-2.compute.amazonaws.com centos@i-0df3060971160cdd6.node.consul"
  exit 1
fi

if [[ -z "$2" ]]; then
  echo "Error: 2nd arg bastion host must be provided. eg:"
  echo "./copy_vault_file_from_bastion.sh main centos@ec2-3-25-143-13.ap-southeast-2.compute.amazonaws.com centos@i-0df3060971160cdd6.node.consul"
  exit 1
fi

if [[ -z "$3" ]]; then
  echo "Error: 3rd arg vault client must be provided. eg: centos@i-00265f3f7614cbbee.node.consul"
  echo "./copy_vault_file_from_bastion.sh main centos@ec2-3-25-143-13.ap-southeast-2.compute.amazonaws.com centos@i-0df3060971160cdd6.node.consul"
  exit 1
fi

if [[ -z "$VAULT_TOKEN" ]]; then
  echo "Provide a vault token to utilise on the private vault client:"
  read -s -p "VAULT_TOKEN: " VAULT_TOKEN
fi

resourcetier="$1"
host1="$2"
host2="$3"

# Log the given message. All logs are written to stderr with a timestamp.
function log {
 local -r message="$1"
 local -r timestamp=$(date +"%Y-%m-%d %H:%M:%S")
 >&2 echo -e "$timestamp $message"
}

log "Requesting files from vault to client in private subnet"
ssh -o ProxyCommand="ssh $host1 -W %h:%p" $host2 "VAULT_TOKEN=$VAULT_TOKEN bash -s" < ./request_vault_file.sh $resourcetier

function retrieve_file {
  local -r source_path="$1"
  local -r target_path="$SCRIPTDIR/../openvpn_config/$(basename $source_path)"

  scp -i ~/.ssh/id_rsa-cert.pub -i ~/.ssh/id_rsa -o ProxyCommand="ssh -i ~/.ssh/id_rsa-cert.pub -i ~/.ssh/id_rsa -W %h:%p $host1" $host2:$source_path "$target_path"
  chmod 0600 "$target_path"
  
  [[ -s "$target_path" ]] && exit_status=0 || exit_status=1
  if [[ $exit_status -eq 1 ]]; then
    echo "Error retrieving file"
    exit 1
  else 
    echo "Success"
  fi
}

# Retrieve previously generated secrets from Vault.  Would be better if we can use vault as an intermediary to generate certs.

retrieve_file "/home/centos/tmp/usr/local/openvpn_as/scripts/seperate/client.ovpn"

cp $SCRIPTDIR/../openvpn_config/client.ovpn $SCRIPTDIR/../openvpn_config/openvpn.conf

log "...Cleaning up"
ssh -o ProxyCommand="ssh $host1 -W %h:%p" $host2 "sudo rm -frv /home/centos/tmp/*"

echo "Done."
cd "$EXECDIR"