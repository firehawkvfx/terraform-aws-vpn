#!/bin/bash

### GENERAL FUNCTIONS FOR ALL INSTALLS

# trap ctrl-c and call ctrl_c()
trap ctrl_c INT
function ctrl_c() {
        printf "\n** CTRL-C ** EXITING...\n"
        exit
}
to_abs_path() {
  python -c "import os; print os.path.abspath('$1')"
}
# This is the directory of the current script
SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
SCRIPTDIR=$(to_abs_path $SCRIPTDIR)
printf "\n...checking scripts directory at $SCRIPTDIR\n\n"
# source an exit test to bail if non zero exit code is produced.
. $SCRIPTDIR/exit_test.sh

argument="$1"

echo "Argument $1"
echo ""
ARGS=''

cd /deployuser

### Get s3 access keys from terraform ###

tf_action="apply"

# if [[ -z $argument ]] ; then
#   echo "Error! you must specify an environment --dev or --prod" 1>&2
#   exit 64
# else
#   case $argument in
#     -d|--dev)
#       ARGS='--dev'
#       echo "using dev environment"
#       source ./update_vars.sh --dev --init; exit_test
#       ;;
#     -p|--prod)
#       ARGS='--prod'
#       echo "using prod environment"
#       source ./update_vars.sh --prod --init; exit_test
#       ;;
#     -p|--plan)
#       tf_action="plan"
#       echo "using prod environment"
#       source ./update_vars.sh --prod --init; exit_test
#       ;;
#     *)
#       raise_error "Unknown argument: ${argument}"
#       return
#       ;;
#   esac
# fi


# enable promisc mode
ansible-playbook ansible/init.yaml -v --extra-vars "variable_host=localhost delegate_host=localhost variable_user=deployuser configure_gateway=true set_hostname=$openfirehawkserver_name openfirehawkserver_name=$openfirehawkserver_name openfirehawkserver_ip=$openfirehawkserver_ip" --tags "init-host,init,init-packages"; exit_test
# enable ipforwarding
ansible-playbook ansible/openvpn-init.yaml -v --extra-vars "variable_host=localhost" --tags "init"; exit_test
# establish connection - certs must be present
# ansible-playbook ansible/openvpn.yaml -v --extra-vars "variable_host=localhost openvpn_user=$2 openvpn_user_pw=$3"; exit_test
