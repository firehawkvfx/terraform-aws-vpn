#!/bin/bash

set -e

SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )" # The directory of this script

set -x

sudo apt-get install -y awscli jq
sudo DEBIAN_FRONTEND=noninteractive apt-get -y install python3
sudo DEBIAN_FRONTEND=noninteractive apt-get -y install python-apt
sudo apt install -y python3-pip
python3 -m pip install --upgrade pip
python3 -m pip install boto3

# sudo DEBIAN_FRONTEND=noninteractive apt-get install -y python-pip
# LC_ALL=C && sudo pip install boto3
python3 -m pip install --user --upgrade awscli

ssh-keygen -q -b 2048 -t rsa -f $HOME/.ssh/id_rsa -C "" -N ""

# resourcetier=

# $SCRIPTDIR/sign-ssh-key/sign_ssh_key.sh --aws-configure --resourcetier 