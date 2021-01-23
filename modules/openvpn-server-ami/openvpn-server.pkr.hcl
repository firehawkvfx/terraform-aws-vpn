# Produces an Open VPN AMI configured to connect with hashicorp vault.
# Ensure you first build the ./base-ami first to produce a manifest.
# The base-ami is used to build this ami.

variable "aws_region" {
  type    = string
  default = null
}

variable "ca_public_key_path" {
  type    = string
  default = "/home/ec2-user/.ssh/tls/ca.crt.pem"
}

variable "resourcetier" {
  type = string
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

variable "vpc_id" {
  type = string
}

variable "security_group_id" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "consul_cluster_tag_key" {
  type = string
}

variable "consul_cluster_tag_value" {
  type = string
}

variable "openvpn_server_base_ami" {
  type = string
}

locals {
  timestamp           = regex_replace(timestamp(), "[- TZ:]", "")
  template_dir        = path.root
  private_subnet1     = vault("/${var.resourcetier}/data/network/private_subnet1", "value")
  public_subnet1      = vault("/${var.resourcetier}/data/network/public_subnet1", "value")
  remote_subnet_cidr  = vault("/${var.resourcetier}/data/network/remote_subnet_cidr", "value")
  vpn_cidr            = vault("/${var.resourcetier}/data/network/vpn_cidr", "value")
  client_network      = element( split("/", vault("/${var.resourcetier}/data/network/vpn_cidr", "value") ), 0 )
  client_netmask_bits = element( split("/", vault("/${var.resourcetier}/data/network/vpn_cidr", "value") ), 1 )
}

source "amazon-ebs" "openvpn-server-ami" {
  ami_description      = "An Open VPN Access Server AMI configured for Firehawk"
  ami_name             = "firehawk-openvpn-server-${local.timestamp}-{{uuid}}"
  instance_type        = "t2.micro"
  region               = "${var.aws_region}"
  iam_instance_profile = "provisioner_instance_role_pipeid0"
  source_ami           = "${var.openvpn_server_base_ami}"
  user_data            = <<EOF
#! /bin/bash
admin_user=openvpnas
admin_pw=''
EOF
  ssh_username         = "openvpnas"
  vpc_id               = "${var.vpc_id}"
  subnet_id            = "${var.subnet_id}"
  security_group_id    = "${var.security_group_id}"
}

# source "amazon-ebs" "openvpn-server-ami" { # Open vpn server requires vault and consul, so we build it here as well.
#   ami_description = "An Open VPN Access Server AMI configured for Firehawk"
#   ami_name        = "firehawk-openvpn-server-${local.timestamp}-{{uuid}}"
#   instance_type   = "t2.micro"
#   region          = "${var.aws_region}"
#   # user_data = "admin_user=openvpnas; admin_pw=openvpnas"
#   user_data = <<EOF
# #! /bin/bash
# admin_user=openvpnas
# admin_pw=''
# EOF
#   # user_data_file  = "${local.template_dir}/openvpn_user_data.sh"
#   source_ami_filter {
#     filters = {
#       description  = "OpenVPN Access Server 2.8.3 publisher image from https://www.openvpn.net/."
#       product-code = "f2ew2wrz425a1jagnifd02u5t"
#     }
#     most_recent = true
#     owners      = ["679593333241"]
#   }
#   ssh_username = "openvpnas"
# }

build {
  sources = [
    "source.amazon-ebs.openvpn-server-ami"
  ]
  provisioner "shell" {
    inline = [
      "echo 'init success'",
      "sudo echo 'sudo echo test'",
      "unset HISTFILE",
      "history -cw",
      "echo === Waiting for Cloud-Init ===",
      "timeout 180 /bin/bash -c 'until stat /var/lib/cloud/instance/boot-finished &>/dev/null; do echo waiting...; sleep 6; done'",
      "echo === System Packages ===",
      "echo 'Connected success. Wait for updates to finish...'", # Open VPN AMI runs apt daily update which must end before we continue.
      "sudo systemd-run --property='After=apt-daily.service apt-daily-upgrade.service' --wait /bin/true; echo \"exit $?\""
    ]
    environment_vars = ["DEBIAN_FRONTEND=noninteractive"]
    inline_shebang   = "/bin/bash -e"
  }

  # provisioner "shell" {
  #   inline_shebang = "/bin/bash -e"
  #   # only           = ["amazon-ebs.openvpn-server-ami"]
  #   environment_vars = ["DEBIAN_FRONTEND=noninteractive"]
  #   inline         = [
  #     "export SHOWCOMMANDS=true; set -x",
  #     # "lsb_release -a",
  #     # "ps aux | grep [a]pt",
  #     "sudo cat /etc/systemd/system.conf",
  #     "sudo chown openvpnas:openvpnas /home/openvpnas; echo \"exit $?\"",
  #     "echo 'debconf debconf/frontend select Noninteractive' | sudo debconf-set-selections; echo \"exit $?\"",
  #     "ls -ltriah /var/cache/debconf/passwords.dat; echo \"exit $?\"",
  #     "ls -ltriah /var/cache/; echo \"exit $?\""
  #   ]
  # }

  # provisioner "shell" {
  #   inline_shebang = "/bin/bash -e"
  #   # only           = ["amazon-ebs.openvpn-server-ami"]
  #   environment_vars = ["DEBIAN_FRONTEND=noninteractive"]
  #   valid_exit_codes = [0,1] # ignore exit code.  this requirement is a bug in the open vpn ami.
  #   inline         = [
  #     # "sudo apt -y install dialog || exit 0" # supressing exit code.
  #     "sudo apt -y install dialog; echo \"exit $?\"" # supressing exit code.
  #   ]
  # }

  # provisioner "shell" {
  #   inline_shebang = "/bin/bash -e"
  #   # only           = ["amazon-ebs.openvpn-server-ami"]
  #   environment_vars = ["DEBIAN_FRONTEND=noninteractive"]
  #   inline         = [
  #     "DEBIAN_FRONTEND=noninteractive sudo apt-get install -y -q; echo \"exit $?\""
  #   ]
  # }

  # provisioner "shell" {
  #   inline_shebang = "/bin/bash -e"
  #   # only           = ["amazon-ebs.openvpn-server-ami"]
  #   environment_vars = ["DEBIAN_FRONTEND=noninteractive"]
  #   inline         = [
  #     "echo 'debconf debconf/frontend select Noninteractive' | sudo debconf-set-selections", 
  #     "sudo apt-get install -y -q"
  #   ]
  # }

  ### Public cert block to verify other consul agents ###

  provisioner "shell" {
    inline = ["mkdir -p /tmp/terraform-aws-vault/modules"]
  }

  provisioner "file" {
    destination = "/tmp/terraform-aws-vault/modules"
    source      = "${local.template_dir}/../terraform-aws-vault/modules/"
  }

  provisioner "file" {
    destination = "/tmp/sign-request.py"
    source      = "${local.template_dir}/auth/sign-request.py"
  }
  provisioner "file" {
    destination = "/tmp/ca.crt.pem"
    source      = "${var.ca_public_key_path}"
  }
  provisioner "shell" {
    inline = [
      "if [[ '${var.install_auth_signing_script}' == 'true' ]]; then",
      "sudo mkdir -p /opt/vault/scripts/",
      "sudo mv /tmp/sign-request.py /opt/vault/scripts/",
      "else",
      "sudo rm /tmp/sign-request.py",
      "fi",
      "sudo mkdir -p /opt/vault/tls/",
      "sudo mv /tmp/ca.crt.pem /opt/vault/tls/",
      "sudo chmod -R 600 /opt/vault/tls",
      "sudo chmod 700 /opt/vault/tls",
      "sudo /tmp/terraform-aws-vault/modules/update-certificate-store/update-certificate-store --cert-file-path /opt/vault/tls/ca.crt.pem"
    ]
    inline_shebang = "/bin/bash -e"
  }
  provisioner "shell" {
    inline         = ["sudo systemd-run --property='After=apt-daily.service apt-daily-upgrade.service' --wait /bin/true"]
    inline_shebang = "/bin/bash -e"
    only           = ["amazon-ebs.ubuntu18-ami"]
  }
  provisioner "shell" {
    inline         = ["echo 'debconf debconf/frontend select Noninteractive' | sudo debconf-set-selections", "sudo apt-get install -y -q", "sudo apt-get -y update", "sudo apt-get install -y git"]
    inline_shebang = "/bin/bash -e"
    only           = ["amazon-ebs.ubuntu16-ami", "amazon-ebs.ubuntu18-ami"]
  }

  ### End public cert block to verify other consul agents ###

  # provisioner "shell" {
  #   inline_shebang = "/bin/bash -e"
  #   # only           = ["amazon-ebs.openvpn-server-ami"]
  #   environment_vars = ["DEBIAN_FRONTEND=noninteractive"]
  #   inline         = [
  #     "sudo apt-get -y update"
  #   ]
  # }

  # provisioner "shell" {
  #   inline_shebang = "/bin/bash -e"
  #   # only           = ["amazon-ebs.openvpn-server-ami"]
  #   environment_vars = ["DEBIAN_FRONTEND=noninteractive"]
  #   inline         = [ 
  #     "sudo apt-get install dpkg -y"
  #   ]
  # }

  # provisioner "shell" {
  #   inline_shebang = "/bin/bash -e"
  #   # only           = ["amazon-ebs.openvpn-server-ami"]
  #   environment_vars = ["DEBIAN_FRONTEND=noninteractive"]
  #   inline         = [ 
  #     "sudo apt-get -y install python3",
  #     "sudo apt-get -y install python-apt",
  #     "sudo apt install -y python3-pip",
  #     "python3 -m pip install --upgrade pip",
  #     "python3 -m pip install boto3",
  #     "python3 -m pip --version",
  #     "sudo apt-get install -y git",
  #     "echo '...Finished bootstrapping'"
  #   ]
  # }

  provisioner "ansible" {
    extra_arguments = [
      "-v",
      "--extra-vars",
      "variable_host=default variable_connect_as_user=openvpnas variable_user=openvpnas variable_become_user=openvpnas delegate_host=localhost",
      "--skip-tags",
      "user_access"
    ]
    playbook_file    = "./ansible/aws_cli_ec2_install.yaml"
    collections_path = "./ansible/collections"
    roles_path       = "./ansible/roles"
    ansible_env_vars = ["ANSIBLE_CONFIG=ansible/ansible.cfg"]
    galaxy_file      = "./requirements.yml"
    # only           = ["amazon-ebs.openvpn-server-ami"]
  }

  provisioner "shell" {
    inline = ["mkdir -p /tmp/terraform-aws-vault/modules"]
  }

  provisioner "file" {
    destination = "/tmp/terraform-aws-vault/modules"
    source      = "${local.template_dir}/../terraform-aws-vault/modules/"
  }

  provisioner "file" {
    destination = "/tmp/sign-request.py"
    source      = "${local.template_dir}/auth/sign-request.py"
  }
  provisioner "file" {
    destination = "/tmp/ca.crt.pem"
    source      = "${var.ca_public_key_path}"
  }

  ### This block will install Vault and Consul Agent

  provisioner "shell" { # Vault client probably wont be installed on bastions in future, but most hosts that will authenticate will require it.
    inline = [
      "if test -n '${var.vault_download_url}'; then",
      " /tmp/terraform-aws-vault/modules/install-vault/install-vault --download-url ${var.vault_download_url};",
      "else",
      " /tmp/terraform-aws-vault/modules/install-vault/install-vault --version ${var.vault_version};",
      "fi"
    ]
  }

  provisioner "shell" {
    inline = [
      "sudo apt-get install -y git",
      "if [[ '${var.install_auth_signing_script}' == 'true' ]]; then",
      "sudo apt-get install -y python-pip",
      "LC_ALL=C && sudo pip install boto3",
    "fi"]
    inline_shebang = "/bin/bash -e"
    # only           = ["amazon-ebs.ubuntu16-ami", "amazon-ebs.ubuntu18-ami"]
  }

  provisioner "shell" {
    inline = [
      "git clone --branch ${var.consul_module_version} https://github.com/hashicorp/terraform-aws-consul.git /tmp/terraform-aws-consul",
      "if test -n \"${var.consul_download_url}\"; then",
      " /tmp/terraform-aws-consul/modules/install-consul/install-consul --download-url ${var.consul_download_url};",
      "else",
      " /tmp/terraform-aws-consul/modules/install-consul/install-consul --version ${var.consul_version};",
    "fi"]
  }

  # provisioner "file" { # the default resolv conf may not be configured correctly since it has a ref to non FQDN hostname.  this may break again if it is being misconfigured on boot which has been observed in ubuntu 18
  #   destination = "/tmp/resolv.conf"
  #   source      = "${local.template_dir}/resolv.conf"
  # }

  # provisioner "shell" {
  #   inline = [
  #     "set -x; sudo mv /tmp/resolv.conf /run/systemd/resolve/resolv.conf",
  #     "set -x; sudo cat /etc/resolv.conf",
  #     "set -x; sudo cat /run/systemd/resolve/resolv.conf",
  #     "/tmp/terraform-aws-consul/modules/setup-systemd-resolved/setup-systemd-resolved",
  #     "set -x; sudo cat /run/systemd/resolve/resolv.conf",
  #     "sudo unlink /etc/resolv.conf",
  #     "sudo ln -s /run/systemd/resolve/resolv.conf /etc/resolv.conf", # resolve.conf initial link isn't configured with a sane default.
  #     "set -x; sudo cat /etc/resolv.conf",
  #     "sudo systemctl daemon-reload",
  #     "echo 'is the host name in /etc/hostname and /etc/hosts ?'",
  #     "sudo cat /etc/hostname",
  #     "sudo cat /etc/hosts"
  #   ]
  #   # only   = ["amazon-ebs.ubuntu18-ami"]
  # }

  provisioner "shell" { # Generate certificates with vault.
    inline = [
      "set -x; sudo sed -i \"s/#Domains=/Domains=~service.consul./g\" /etc/systemd/resolved.conf",
      "set -x; /tmp/terraform-aws-consul/modules/setup-systemd-resolved/setup-systemd-resolved",
      "set -x; sudo systemctl daemon-reload",
      "set -x; sudo systemctl restart systemd-resolved",
      "set -x; sudo cat /etc/systemd/resolved.conf",
      "set -x; sudo /opt/consul/bin/run-consul --client --cluster-tag-key \"${var.consul_cluster_tag_key}\" --cluster-tag-value \"${var.consul_cluster_tag_value}\"", # this is normally done with user data but dont for convenience here
      "set -x; consul members list",
      "set -x; dig $(hostname) | awk '/^;; ANSWER SECTION:$/ { getline ; print $5 ; exit }'", # check localhost resolve's
      # test=$(ls -A); if [[ $? != 0 ]]; then; echo "Command failed."; fi
      "set -x; dig @127.0.0.1 vault.service.consul | awk '/^;; ANSWER SECTION:$/ { getline ; print $5 ; exit }'", # check consul will resolve vault
      "set -x; dig @localhost vault.service.consul | awk '/^;; ANSWER SECTION:$/ { getline ; print $5 ; exit }'", # check localhost will resolve vault
      "set -x; dig vault.service.consul | awk '/^;; ANSWER SECTION:$/ { getline ; print $5 ; exit }'", # check default lookup will resolve vault
      ]
  }

  provisioner "shell" {
    expect_disconnect = true
    inline            = ["set -x; sudo reboot; sleep 60"]
    environment_vars = ["DEBIAN_FRONTEND=noninteractive"]
    inline_shebang   = "/bin/bash -e"
  }
  provisioner "shell" {
    expect_disconnect = true
    inline            = ["set -x; sleep 120"]
    # only              = ["amazon-ebs.centos7-ami"]
  }


  # provisioner "shell" { # We install with bash instead of ansible due to some permissions and connections issues, probably to do with ansible tmp dir on the official open vpn AMI.
  #   inline = [
  #     "set -x; sudo apt install -y fping",
  #     "sleep 60",
  #     # "python3 -m pip install apt",
  #     # "set -x; python3 -m pip install netaddr",
  #     # "sleep 60",
  #     "set -x; python3 -m pip install passlib",
  #     "sleep 60",
  #     "set -x; python3 -m pip install requests",
  #     "sleep 60",
  #     "set -x; python3 -m pip install pexpect",
  #     "sleep 60",
  #     "set -x; sudo apt-get install -y whois",
  #     "sleep 60",
  #     "set -x; sudo apt-get install -y zip",
  #     "sleep 60",
  #     "set -x; sudo apt-get install -y rng-tools ",
  #     "sleep 60",
  #     "set -x; sudo apt-get install -y gpgv2",
  #     "sleep 60",
  #     "set -x; sudo apt-get install -y jq",
  #     "sleep 60",
  #     "set -x; sudo apt-get install -y nfs-common",
  #     "sleep 60",
  #     # "set -x; sudo apt-get install -y whois zip rng-tools gpgv2 jq nfs-common",
  #     # "sleep 60",
  #     "set -x; sudo apt-get install -y inotify-tools", # Used to catch existance of interrupt file https://stackoverflow.com/questions/18893283/how-to-proceed-in-the-script-if-file-exists
  #     "sleep 60",
  #     # "set -x; sudo apt-get install -y dnsmasq", # not for ubuntu 18 - we now use systemd-resolvd
  #     # "sleep 60"
  #   ]
  #   environment_vars = ["DEBIAN_FRONTEND=noninteractive"]
  #   inline_shebang   = "/bin/bash -e"
  # }

  # gateway vars
  # vpn_address=${local.vpn_address} private_domain_name=${var.private_domain_name} 
  # private_ip=${local.private_ip} 

  # server vars, try to handle this with user data instead.


  provisioner "ansible" {
    extra_arguments = [
      "-v",
      "--extra-vars",
      "ansible_distribution=Ubuntu ansible_python_interpreter=/usr/bin/python package_python_interpreter=/usr/bin/python variable_host=default variable_connect_as_user=openvpnas variable_user=openvpnas variable_become_user=openvpnas delegate_host=localhost",
      "--skip-tags",
      "user_access"
    ]
    playbook_file    = "./ansible/init-packages.yaml"
    collections_path = "./ansible/collections"
    roles_path       = "./ansible/roles"
    ansible_env_vars = ["ANSIBLE_CONFIG=ansible/ansible.cfg"]
    galaxy_file      = "./requirements.yml"
    # only           = ["amazon-ebs.openvpn-server-ami"]
  }

  provisioner "shell" {
    expect_disconnect = true
    inline            = ["set -x; sudo reboot"]
    # only              = ["amazon-ebs.centos7-ami"]
  }
  provisioner "shell" {
    expect_disconnect = true
    inline            = ["set -x; sleep 120"]
    # only              = ["amazon-ebs.centos7-ami"]
  }
  provisioner "shell" {
    inline = [
      "echo 'init success'",
      "sudo echo 'sudo echo test'",
      "unset HISTFILE",
      "history -cw",
      "echo === Waiting for Cloud-Init ===",
      "timeout 180 /bin/bash -c 'until stat /var/lib/cloud/instance/boot-finished &>/dev/null; do echo waiting...; sleep 6; done'",
      "echo === System Packages ===",
      "echo 'Connected success. Wait for updates to finish...'", # Open VPN AMI runs apt daily update which must end before we continue.
      "sudo systemd-run --property='After=apt-daily.service apt-daily-upgrade.service' --wait /bin/true; echo \"Done: exit code $?\""
    ]
    environment_vars = ["DEBIAN_FRONTEND=noninteractive"]
    inline_shebang   = "/bin/bash -e"
  }
  provisioner "shell" {
    inline            = ["set -x; sleep 120"]
    # only              = ["amazon-ebs.centos7-ami"]
  }

  provisioner "ansible" {
    extra_arguments = [
      "-v",
      "--extra-vars",
      "ansible_distribution=Ubuntu ansible_python_interpreter=/usr/bin/python package_python_interpreter=/usr/bin/python variable_host=default variable_connect_as_user=openvpnas variable_user=openvpnas variable_become_user=openvpnas delegate_host=localhost private_subnet1=${local.private_subnet1} public_subnet1=${local.public_subnet1} remote_subnet_cidr=${local.remote_subnet_cidr} client_network=${local.client_network} client_netmask_bits=${local.client_netmask_bits}",
      "--skip-tags",
      "user_access"
    ]
    playbook_file    = "./ansible/openvpn.yaml"
    collections_path = "./ansible/collections"
    roles_path       = "./ansible/roles"
    ansible_env_vars = ["ANSIBLE_CONFIG=ansible/ansible.cfg"]
    galaxy_file      = "./requirements.yml"
    # only           = ["amazon-ebs.openvpn-server-ami"]
  }

  post-processor "manifest" {
    output     = "${local.template_dir}/manifest.json"
    strip_path = true
    custom_data = {
      timestamp = "${local.timestamp}"
    }
  }
}
