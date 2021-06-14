#!/bin/bash

set -e

EXECDIR="$(pwd)"
SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )" # The directory of this script
readonly SCRIPT_NAME="$(basename "$0")"
cd "$SCRIPTDIR"

readonly DEFAULT_resourcetier="$TF_VAR_resourcetier"
readonly DEFAULT_PUBLIC_KEY="$HOME/.ssh/id_rsa.pub"
readonly DEFAULT_TRUSTED_CA="/etc/ssh/trusted-user-ca-keys.pem"
readonly DEFAULT_SSH_KNOWN_HOSTS="/etc/ssh/ssh_known_hosts"
readonly DEFAULT_SSH_KNOWN_HOSTS_FRAGMENT=$HOME/.ssh/ssh_known_hosts_fragment
readonly DEFAULT_POLL_DURATION=3

# These helper functions are from the sign_ssh_key.sh Hashicorp script

function print_usage {
  echo
  echo "Usage: sign_ssh_key.sh [OPTIONS]"
  echo
  echo "If authenticated to Vault, signs a public key with Vault for use as an SSH client, generating a public certificate in the same directory as the public key with the suffix '-cert.pub'."
  echo
  echo "Options:"
  echo
  echo -e "  --public-key\tThe public key to sign (Must end in .pub lowercase). Optional. Default: $DEFAULT_PUBLIC_KEY."
  echo
  echo "Example: Sign this hosts public key with Vault."
  echo
  echo "  sign_ssh_key.sh"
  echo
  echo "Example: Sign a non-default public key with Vault.  If the key does not exist at this location, user will be prompted to paste the key in."
  echo
  echo "  sign_ssh_key.sh --public-key ~/.ssh/remote_host/id_rsa.pub"
  echo
  echo "Example: On a Remote host configure a provided cert file and trusted CA file where vault access is unavailable."
  echo
  echo "  sign_ssh_key.sh --trusted-ca ~/Downloads/trusted-user-ca-keys.pem --cert ~/Downloads/id_rsa-cert.pub"
}

function log {
  local -r level="$1"
  local -r message="$2"
  local -r timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  >&2 echo -e "${timestamp} [${level}] [$SCRIPT_NAME] ${message}"
}

function log_info {
  local -r message="$1"
  log "INFO" "$message"
}

function log_warn {
  local -r message="$1"
  log "WARN" "$message"
}

function log_error {
  local -r message="$1"
  log "ERROR" "$message"
}

function error_if_empty {
  if [[ -z "$2" ]]; then
    log_error "$1"
  fi
  return
}

function assert_not_empty {
  local -r arg_name="$1"
  local -r arg_value="$2"

  if [[ -z "$arg_value" ]]; then
    log_error "The value for '$arg_name' cannot be empty"
    print_usage
    exit 1
  fi
}

function request_trusted_ca {
  local -r trusted_ca="$1"
  # Aquire the public CA cert to approve an authority for known hosts.
  vault read -field=public_key ssh-client-signer/config/ca | sudo tee $trusted_ca
}

function configure_trusted_ca {
  local -r trusted_ca="$1"
  sudo chmod 0644 "$trusted_ca"
  # If TrustedUserCAKeys not defined, then add it to sshd_config
  sudo grep -q "^TrustedUserCAKeys" /etc/ssh/sshd_config || echo 'TrustedUserCAKeys' | sudo tee -a /etc/ssh/sshd_config
  # Ensure the value for TrustedUserCAKeys is configured correctly
  sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.tmp
  sudo python3 $SCRIPTDIR/replace_value.py -f /etc/ssh/sshd_config.tmp "TrustedUserCAKeys" " $trusted_ca"
  sudo mv /etc/ssh/sshd_config.tmp /etc/ssh/sshd_config # if the python script doesn't error, then we update the original.  If this file were to be misconfigured it will break SSH and your instance.
}

function configure_cert_restart {
  local -r cert="$1"
  sudo chmod 0644 "$cert"

  # View result metadata
  ssh-keygen -Lf "$cert"

  log_info "Restarting SSH service..."
  # mac / centos / amazon linux, restart ssh service
  if [[ "$OSTYPE" == "darwin"* ]]; then
    sudo launchctl unload /System/Library/LaunchDaemons/ssh.plist
    sudo launchctl load -w /System/Library/LaunchDaemons/ssh.plist
  else
    sudo systemctl restart sshd
  fi

  log_info "Done signing SSH client key."
}

function request_sign_public_key {
  local -r public_key="$1"
  local -r trusted_ca="$2"
  local -r cert="$3"
  local -r resourcetier="$4"
  local -r ssh_known_hosts="$DEFAULT_SSH_KNOWN_HOSTS"

  if [[ "$public_key"!="$DEFAULT_PUBLIC_KEY" ]]; then
    log "Copying $trusted_ca to $(dirname $public_key). Ensure you download this file to $trusted_ca if you intend to connect from a remote client."
    sudo cp $trusted_ca $(dirname $public_key)
    log "Configuring known hosts. To ensure $ssh_known_hosts is current before copying to homedir for download."
    $SCRIPTDIR/../known-hosts/known_hosts.sh --resourcetier "$resourcetier"
    log "Copying $DEFAULT_SSH_KNOWN_HOSTS_FRAGMENT to $(dirname $public_key).  Ensure you download this file to a remote client if you intend to connect from that client, ensuring ssh hosts have valid certs."
    # sudo rm -fv "$(dirname $public_key)/ssh_known_hosts_fragment" # if the file is the same, cp will raise a non 0 exit code, so we remove it.
    FILE1=$DEFAULT_SSH_KNOWN_HOSTS_FRAGMENT
    FILE2="$(dirname $public_key)/$(basename $DEFAULT_SSH_KNOWN_HOSTS_FRAGMENT)"
    if [ "$(stat -L -c %d:%i FILE1)" = "$(stat -L -c %d:%i FILE2)" ]; then
      echo "FILE1 and FILE2 refer to a single file, with one inode, on one device. Skip copy."
    else
      sudo cp -f "$FILE1" "$FILE2"
    fi
  fi

  log_info "Signing public key"
  
  vault write ssh-client-signer/sign/ssh-role \
      public_key=@$public_key

  # Save the signed public cert
  vault write -field=signed_key ssh-client-signer/sign/ssh-role \
      public_key=@$public_key > $cert
}

function get_trusted_ca_ssm {
  local -r trusted_ca="$1"
  local -r resourcetier="$2"
  log_info "Validating that credentials are configured..."
  aws sts get-caller-identity
  log_info "Updating: $trusted_ca"
  aws ssm get-parameters --names /firehawk/resourcetier/$resourcetier/trusted_ca | jq -r '.Parameters[0].Value' | sudo tee "$trusted_ca"
}

function get_cert_ssm {
  local -r cert="$1"
  local -r resourcetier="$2"
  log_info "Updating: $cert"
  aws ssm get-parameters --names /firehawk/resourcetier/$resourcetier/onsite_user_public_cert | jq -r '.Parameters[0].Value' | tee "$cert"
}

function ssm_get_parm {
  local -r parm_name="$1"

  output=$(aws ssm get-parameters --with-decryption --names ${parm_name}) && exit_status=0 || exit_status=$?

  invalid=$(echo ${output} | jq -r .'InvalidParameters | length')
  if [[ $exit_status -eq 0 && $invalid -eq 0 ]]; then
      log "Result: ${output}"
      value=$(echo ${output} | jq -r '.Parameters[0].Value')
      echo "$value"
      return
  fi
  log "...Failed retrieving: ${parm_name}"
  log "Result: ${output}"
}

function sqs_send_file {
  local -r resourcetier="$1"
  local -r file_path="$2"
  local -r parm_name="$3"
  sqs_queue_url="$(ssm_get_parm $parm_name)"
  error_if_empty "Could not resolve $parm_name" "$sqs_queue_url"
  file_content="$(cat $file_path)"
  aws sqs send-message --queue-url $sqs_queue_url --message-body "$file_content" --message-group-id "$resourcetier"
}

function poll_public_key {
  local -r resourcetier="$1"
  local -r parm_name="/firehawk/resourcetier/$resourcetier/sqs_cloud_in_cert_url"
  local -r sqs_queue_url="$(ssm_get_parm "$parm_name")"

  log "...Polling SQS queue for your remote host's public key"
  poll="true"
  while [[ "$poll" == "true" ]]; do
    local msg="$(aws sqs receive-message --queue-url $sqs_queue_url)"
    if [[ ! -z "$msg" ]]; then
      poll="false"
      reciept_handle="$(echo "$msg" | jq -r '.Messages[] | .ReceiptHandle')"
      aws sqs delete-message --queue-url $sqs_queue_url --receipt-handle $reciept_handle && echo "$msg" | jq -r '.Messages[] | .Body' 
    fi
    log "...Waiting $DEFAULT_POLL_DURATION seconds before retry."
    sleep $DEFAULT_POLL_DURATION
  done
}

function poll_public_signed_cert {
  local -r resourcetier="$1"
  local -r parm_name="/firehawk/resourcetier/$resourcetier/sqs_remote_in_cert_url"
  local -r sqs_queue_url="$(ssm_get_parm "$parm_name")"

  log "...Polling SQS queue for your remote host's signed cert"
  poll="true"
  while [[ "$poll" == "true" ]]; do
    local msg="$(aws sqs receive-message --queue-url $sqs_queue_url)"
    if [[ ! -z "$msg" ]]; then
      poll="false"
      reciept_handle="$(echo "$msg" | jq -r '.Messages[] | .ReceiptHandle')"
      aws sqs delete-message --queue-url $sqs_queue_url --receipt-handle $reciept_handle && echo "$msg" | jq -r '.Messages[] | .Body' 
    fi
    log "...Waiting $DEFAULT_POLL_DURATION seconds before retry."
    sleep $DEFAULT_POLL_DURATION
  done
}

# You should be able to ssh into a target host:
# ssh -i signed-cert.pub -i ~/.ssh/id_rsa username@10.0.23.5

function install {
  local public_key="$DEFAULT_PUBLIC_KEY"
  local resourcetier="$DEFAULT_resourcetier"
  local trusted_ca=""
  local cert=""
  local aquire_pubkey_certs_via_ssm="false"
  local trusted_ca_via_ssm="false"
  local generate_aws_key="false"
  local sqs_get_public_key="false"
  local sqs_send_signed_cert="false"
  local aws_access_key=""
  local aws_secret_key=""
  local aws_configure="false"
  local public_key_content=""
  local poll_public_cert="false"
  local configure_cert="true"
  
  while [[ $# > 0 ]]; do
    local key="$1"

    case "$key" in
      --public-key)
        assert_not_empty "$key" "$2"
        public_key="$2"
        shift
        ;;
      --trusted-ca)
        assert_not_empty "$key" "$2"
        trusted_ca="$2"
        shift
        ;;
      --cert)
        assert_not_empty "$key" "$2"
        cert="$2"
        shift
        ;;
      --resourcetier)
        resourcetier="$2"
        shift
        ;;
      --ssm)
        aquire_pubkey_certs_via_ssm="true"
        trusted_ca_via_ssm="true"
        ;;
      --generate-aws-key)
        generate_aws_key="true"
        sqs_get_public_key="true"
        sqs_send_signed_cert="true"
        ;;
      --aws-configure) # Provide an access key on a remote client to send public key and recieve cert via an sqs queue
        aws_configure="true"
        trusted_ca_via_ssm="true"
        poll_public_cert="true"
        ;;
      --help)
        print_usage
        exit
        ;;
      *)
        log_error "Unrecognized argument: $key"
        print_usage
        exit 1
        ;;
    esac

    shift
  done

  error_if_empty "Argument resourcetier or env var TF_VAR_resourcetier not provided" "$resourcetier"

  if [[ "$generate_aws_key" == "true" ]]; then
    log ""
    log "...Generating AWS credentials.  Configure your remote host with these keys to automate SSH and VPN auth."
    vault read aws/creds/aws-creds-ssm-parameters-ssh-certs
  fi

  if [[ "$sqs_get_public_key" == "true" ]]; then
    configure_cert="false" # if we are getting a remote pub key to produce a cert, then this host will not need to use the result for ssh.
    public_key_content="$(poll_public_key $resourcetier)" # poll for a public key and save it to a file
    log "public_key_content: $public_key_content"
    public_key="$HOME/.ssh/remote_host/id_rsa.pub"

    target="$public_key"
    create_dir="$(dirname ${target})"
    
    log "...Create dir: $create_dir"
    mkdir -p "${create_dir}"
    echo "$public_key_content" | tee "$target"

    if test ! -f "$target"; then
      log "Failed to write: $target"
      exit 1
    fi
  fi

  if [[ "$aws_configure" == "true" ]]; then # we can use an aws secret to provide a channel to post the hosts public key and receive a cert via AWS SQS.
    aws configure # this is an interactive input.
    sqs_send_file "$resourcetier" "$HOME/.ssh/id_rsa.pub" "/firehawk/resourcetier/$resourcetier/sqs_cloud_in_cert_url"
  fi

  if [[ "$trusted_ca_via_ssm" == "true" ]]; then
    log_info "Requesting trusted CA via SSM Parameter..."
    trusted_ca="$DEFAULT_TRUSTED_CA"
    get_trusted_ca_ssm $trusted_ca "$resourcetier"
  elif [[ -z "$trusted_ca" ]]; then # if no trusted ca provided, request it from vault and store in default location.
    trusted_ca="$DEFAULT_TRUSTED_CA"
    log_info "Requesting Vault provide the trusted CA..."
    request_trusted_ca "$trusted_ca"
  else
    log_info "Trusted CA path provided. Skipping vault request. Copy to standard path..."
    cp -frv "$trusted_ca" "$DEFAULT_TRUSTED_CA"
    trusted_ca="$DEFAULT_TRUSTED_CA"
  fi

  log_info "Configure this host to use trusted CA"
  configure_trusted_ca "$trusted_ca" # configure trusted ca for our host

  if [[ "$poll_public_cert" == "true" ]]; then
    log_info "Polling SQS queue for signed cert..."
    public_signed_cert_content="$(poll_public_signed_cert $resourcetier)"
    cert=${public_key/.pub/-cert.pub}
    echo "$public_signed_cert_content" | tee $cert
  elif [[ "$aquire_pubkey_certs_via_ssm" == "true" ]]; then
    log_info "Requesting SSH Cert via SSM Parameter..."
    cert=${public_key/.pub/-cert.pub}
    get_cert_ssm $cert "$resourcetier"
  elif [[ -z "$cert" ]]; then # if no cert provided, request it from vault and store in along side the public key.
    # if public key doesn't exist, allow user to paste it in
    if test ! -f "$public_key"; then
      log_info "Public key not present at location: $public_key"
      log_info "You can paste the contents of the new file here (read the public key on the remote host eg: cat ~/.ssh/id_rsa.pub):"
      mkdir -p $(dirname "$public_key")
      read public_key_content
      echo "$public_key_content" | tee "$public_key"
    fi
    log_info "Requesting Vault sign public key for SSH client..."
    cert=${public_key/.pub/-cert.pub}
    request_sign_public_key "$public_key" "$trusted_ca" "$cert" "$resourcetier"

    if [[ "$sqs_send_signed_cert" == "true" ]]; then
      sqs_send_file "$resourcetier" "$cert" "/firehawk/resourcetier/$resourcetier/sqs_remote_in_cert_url"
    fi
  else
    log_info "Cert path provided: public key already signed. copying to default ssh dir ~/.ssh"
    sudo cp -frv "$cert" ~/.ssh
    cert="$(sudo basename $cert)"
    cert="$HOME/.ssh/$cert"
  fi

  if [[ "$configure_cert" == "true" ]]; then
    log_info "Configure cert for use: $cert"
    configure_cert_restart "$cert"
  fi
  log_info "Complete!"
}

install "$@"

cd $EXECDIR