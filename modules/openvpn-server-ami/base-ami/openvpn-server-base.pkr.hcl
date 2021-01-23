# This open vpn server base ami's primary purpose is to produce an image with apt-get update 
# apt-get update can be unstable on a daily basis so the base ami once successful can be reused for further ami configuration.


variable "aws_region" {
  type = string
  default = null
}

variable "ca_public_key_path" {
  type    = string
  default = "/home/ec2-user/.ssh/tls/ca.crt.pem"
}

variable "resourcetier" {
  type    = string
}

variable "consul_download_url" {
  type    = string
  default = ""
}

variable "consul_module_version" {
  type    = string
  default = "v0.8.0"
}

variable "consul_version" {
  type    = string
  default = "1.8.4"
}

variable "install_auth_signing_script" {
  type    = string
  default = "true"
}

variable "vault_download_url" {
  type    = string
  default = ""
}

variable "vault_version" {
  type    = string
  default = "1.5.5"
}

locals {
  timestamp    = regex_replace(timestamp(), "[- TZ:]", "")
  template_dir = path.root
}

source "amazon-ebs" "openvpn-server-base-ami" { # Open vpn server requires vault and consul, so we build it here as well.
  ami_description = "An Open VPN Access Server AMI configured for Firehawk"
  ami_name        = "firehawk-openvpn-server-base-${local.timestamp}-{{uuid}}"
  instance_type   = "t2.micro"
  region          = "${var.aws_region}"
  user_data = <<EOF
#! /bin/bash
admin_user=openvpnas
admin_pw=''
EOF
  source_ami_filter {
    filters = {
      description  = "OpenVPN Access Server 2.8.3 publisher image from https://www.openvpn.net/."
      product-code = "f2ew2wrz425a1jagnifd02u5t"
    }
    most_recent = true
    owners      = ["679593333241"]
  }
  ssh_username = "openvpnas"
}

build {
  sources = [
    "source.amazon-ebs.openvpn-server-base-ami"
    ]
  provisioner "shell" {
    inline         = [
      "echo 'Init success.'",
      "sudo echo 'Sudo test success.'",
      "unset HISTFILE",
      "history -cw",
      "echo === Waiting for Cloud-Init ===",
      "timeout 180 /bin/bash -c 'until stat /var/lib/cloud/instance/boot-finished &>/dev/null; do echo waiting...; sleep 6; done'",
      "echo === System Packages ===",
      "echo 'Connected success. Wait for updates to finish...'", # Open VPN AMI runs apt daily update which must end before we continue.
      "sudo systemd-run --property='After=apt-daily.service apt-daily-upgrade.service' --wait /bin/true; echo \"exit $?\""
      ]
    environment_vars = ["DEBIAN_FRONTEND=noninteractive"]
    inline_shebang = "/bin/bash -e"
  }
  
  provisioner "shell" {
    inline_shebang = "/bin/bash -e"
    # only           = ["amazon-ebs.openvpn-server-base-ami"]
    environment_vars = ["DEBIAN_FRONTEND=noninteractive"]
    inline         = [
      "export SHOWCOMMANDS=true; set -x",
      "sudo cat /etc/systemd/system.conf",
      "sudo chown openvpnas:openvpnas /home/openvpnas; echo \"exit $?\"",
      "echo 'debconf debconf/frontend select Noninteractive' | sudo debconf-set-selections; echo \"exit $?\"",
      "ls -ltriah /var/cache/debconf/passwords.dat; echo \"exit $?\"",
      "ls -ltriah /var/cache/; echo \"exit $?\""
    ]
  }

  provisioner "shell" {
    inline_shebang = "/bin/bash -e"
    # only           = ["amazon-ebs.openvpn-server-base-ami"]
    environment_vars = ["DEBIAN_FRONTEND=noninteractive"]
    valid_exit_codes = [0,1] # ignore exit code.  this requirement is a bug in the open vpn ami.
    inline         = [
      # "sudo apt -y install dialog || exit 0" # supressing exit code.
      "sudo apt-get -y install dialog; echo \"exit $?\"" # supressing exit code - until dialog is installed, apt-get may produce non zero exist codes.
    ]
  }

  provisioner "shell" {
    inline_shebang = "/bin/bash -e"
    # only           = ["amazon-ebs.openvpn-server-base-ami"]
    environment_vars = ["DEBIAN_FRONTEND=noninteractive"]
    inline         = [
      "DEBIAN_FRONTEND=noninteractive sudo apt-get install -y -q; echo \"exit $?\""
    ]
  }

  provisioner "shell" {
    inline_shebang = "/bin/bash -e"
    # only           = ["amazon-ebs.openvpn-server-base-ami"]
    environment_vars = ["DEBIAN_FRONTEND=noninteractive"]
    inline         = [
      "sudo apt-get -y update",
      "sudo apt-get install dpkg -y"
    ]
  }

  provisioner "shell" {
    inline_shebang = "/bin/bash -e"
    # only           = ["amazon-ebs.openvpn-server-ami"]
    environment_vars = ["DEBIAN_FRONTEND=noninteractive"]
    inline         = [ 
      "sudo apt-get -y install python3",
      "sudo apt-get -y install python-apt",
      "sudo apt install -y python3-pip",
      "python3 -m pip install --upgrade pip",
      "python3 -m pip install boto3",
      "python3 -m pip --version",
      "sudo apt-get install -y git",
      "echo '...Finished bootstrapping'"
    ]
  }

  post-processor "manifest" {
      output = "${local.template_dir}/manifest.json"
      strip_path = true
      custom_data = {
        timestamp = "${local.timestamp}"
      }
  }
}