provider "null" {}

# provider "aws" {}

data "aws_region" "current" {}

locals {
  common_tags = var.common_tags
  vpn_scripts_bucket_name = "nebula.scripts.${var.resourcetier}.firehawkvfx.com"
  # vpn_scripts_bucket_arn = data.aws_s3_bucket.vpn_scripts.arn
  vpn_certs_bucket_name = "nebula.certs.${var.resourcetier}.firehawkvfx.com"
  # vpn_certs_bucket_arn = data.aws_s3_bucket.vpn_certs.arn
}

# data "aws_s3_bucket" "vpn_scripts" {
#   bucket = local.vpn_scripts_bucket_name
# }
# data "aws_s3_bucket" "vpn_certs" {
#   bucket = local.vpn_certs_bucket_name
# }

data "aws_vpc" "primary" {
  count = length(var.vpc_id) > 0 ? 1 : 0
  default = false
  id = var.vpc_id
}

data "aws_internet_gateway" "gw" {
  count = length(var.vpc_id) > 0 ? 1 : 0
  filter {
    name   = "attachment.vpc-id"
    values = [var.vpc_id]
  }
}

data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }
  tags = {
    area = "public"
  }
}

data "aws_subnet" "public" {
  for_each = toset(data.aws_subnets.public.ids)
  id       = each.value
}

data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }
  tags = {
    area = "private"
  }
}

data "aws_subnet" "private" {
  for_each = toset(data.aws_subnets.private.ids)
  id       = each.value
}

data "aws_route_tables" "public" {
  count = length(var.vpc_id) > 0 ? 1 : 0
  vpc_id = var.vpc_id
  tags   = merge(local.common_tags, { "area" : "public" })
}

data "aws_route_tables" "private" {
  count = length(var.vpc_id) > 0 ? 1 : 0
  vpc_id = var.vpc_id
  tags   = merge(local.common_tags, { "area" : "private" })
}

locals {
  mount_path                 = var.resourcetier
  vpc_id                     = var.vpc_id
  vpc_cidr                   = length(data.aws_vpc.primary) > 0 ? data.aws_vpc.primary[0].cidr_block : ""
  aws_internet_gateway       = length(data.aws_internet_gateway.gw) > 0 ? data.aws_internet_gateway.gw[0].id : ""
  public_subnets             = length(data.aws_subnets.public) > 0 ? sort(data.aws_subnets.public.ids) : []
  public_subnet_cidr_blocks  = [for s in data.aws_subnet.public : s.cidr_block]
  private_subnets            = length(data.aws_subnets.private) > 0 ? sort(data.aws_subnets.private.ids) : []
  private_subnet_cidr_blocks = [for s in data.aws_subnet.private : s.cidr_block]
  vpn_cidr                   = var.vpn_cidr
  onsite_private_subnet_cidr = var.onsite_private_subnet_cidr
  onsite_public_ip           = var.onsite_public_ip
  private_route_table_ids    = length(data.aws_route_tables.private) > 0 ? sort(data.aws_route_tables.private[0].ids) : []
  public_route_table_ids     = length(data.aws_route_tables.public) > 0 ? sort(data.aws_route_tables.public[0].ids) : []
  public_domain_name         = "none"
  route_zone_id              = "none"
  instance_name              = "${lookup(local.common_tags, "vpcname", "default")}_openvpn_ec2_pipeid${lookup(local.common_tags, "pipelineid", "0")}"
}
data "terraform_remote_state" "openvpn_profile" { # read the arn with data.terraform_remote_state.packer_profile.outputs.instance_role_arn, or read the profile name with data.terraform_remote_state.packer_profile.outputs.instance_profile_name
  backend = "s3"
  config = {
    bucket = "state.terraform.${var.bucket_extension_vault}"
    key    = "firehawk-main/modules/terraform-aws-iam-profile-openvpn/terraform.tfstate"
    region = data.aws_region.current.name
  }
}

# module "vpn" {
#   source                     = "./modules/tf_aws_openvpn"
#   create_vpn                 = false
#   security_group_attachments = var.security_group_ids
#   example_role_name          = "vpn-server-vault-role" # this authenticates with a dynamically generated secret key
#   name                       = local.instance_name
#   ami                        = var.openvpn_server_ami
#   iam_instance_profile_name  = try(data.terraform_remote_state.openvpn_profile.outputs.instance_profile_name, null) # if destroy after partial deploy, remote state may not have existed.
#   resourcetier               = var.resourcetier
#   conflictkey                = var.conflictkey
#   # VPC Inputs
#   vpc_id                     = local.vpc_id
#   vpc_cidr                   = local.vpc_cidr
#   vpn_cidr                   = local.vpn_cidr
#   combined_vpcs_cidr         = var.combined_vpcs_cidr
#   public_subnet_id           = length(local.public_subnets) > 0 ? local.public_subnets[0] : null
#   remote_vpn_ip_cidr         = "${local.onsite_public_ip}/32"
#   onsite_private_subnet_cidr = local.onsite_private_subnet_cidr
#   private_route_table_ids    = local.private_route_table_ids
#   public_route_table_ids     = local.public_route_table_ids
#   route_public_domain_name   = var.route_public_domain_name
#   igw_id                     = local.aws_internet_gateway
#   public_subnets             = local.public_subnet_cidr_blocks
#   private_subnets            = local.private_subnet_cidr_blocks
#   # EC2 Inputs
#   aws_key_name  = var.aws_key_name # This should be replaced with an admin level ssh cert.
#   instance_type = var.instance_type
#   # Network Routing Inputs.  source destination checks are disable for nat gateways or routing on an instance.
#   source_dest_check = false
#   # DNS Inputs
#   consul_cluster_name    = var.consul_cluster_name
#   consul_cluster_tag_key = var.consul_cluster_tag_key
#   public_domain_name     = local.public_domain_name
#   route_zone_id          = local.route_zone_id
#   # # OpenVPN Inputs
#   openvpn_user       = "openvpnas"
#   openvpn_admin_user = "openvpnas"
#   # SQS
#   sqs_remote_in_vpn = var.sqs_remote_in_vpn
#   host1             = var.host1
#   host2             = var.host2
#   sleep             = var.sleep
#   common_tags       = local.common_tags
# }


# # Create a new VPC

locals {
  multi_account_role_arn  = data.aws_caller_identity.current.account_id
  # permitted_cidr_list_all = concat(module.vpc.public_subnets_cidr_blocks, module.vpc.private_subnets_cidr_blocks, ["192.168.100.0/24"])
}

data "aws_caller_identity" "current" {}

data "aws_ami" "latest_amazon_linux_2" {
  filter {
    name   = "name"
    values = ["*amzn2-ami-hvm-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "block-device-mapping.volume-type"
    values = ["gp2"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  most_recent = true
  owners      = ["amazon"]
}

# module "terraform_aws_iam_profile_lighthouse" {
#   source       = "./modules/terraform-aws-iam-profile-lighthouse"
#   resourcetier = var.resourcetier
#   region       = data.aws_region.current.name
#   bucket_arns  = [local.vpn_certs_bucket_arn, local.vpn_scripts_bucket_arn]
# }

# Allow access from anywhere!
module "terraform_aws_sg_bastion" {
  source = "./modules/terraform-aws-sg-bastion"
  vpc_id = var.vpc_id
}


# TODO raise error if user data failes in tests
resource "aws_instance" "neb_lighthouse" {
  count = var.sleep ? 0 : 1
  instance_type          = "t2.micro"
  ami                    = data.aws_ami.latest_amazon_linux_2.id
  subnet_id              = length(local.public_subnets) > 0 ? local.public_subnets[0] : null
  user_data              = data.template_file.user_data_lighthouse.rendered
  iam_instance_profile   = "lighthouse_instance_role_${var.resourcetier}"
  vpc_security_group_ids = [module.terraform_aws_sg_bastion.security_group_id]
  key_name               = "testnebula"

  user_data_replace_on_change = true
  root_block_device {
    delete_on_termination = true
  }
  tags = {
    Name = "lighthouse1"
  }
}

data "aws_s3_object" "nebula_bootstrap" {
  bucket = local.vpn_scripts_bucket_name
  key    = "nebula_bootstrap.sh"
}

data "template_file" "user_data_lighthouse" {
  template = file("${path.module}/user-data-auth-ssh-host-iam.sh")
  vars = {
    resourcetier        = var.resourcetier
    aws_internal_domain = "${data.aws_region.current.name}.compute.internal"
    nebula_name         = "lighthouse1"
    aws_region          = data.aws_region.current.name
    bootstrap_serial    = data.aws_s3_object.nebula_bootstrap.etag
    lighthouse          = "true"
  }
}

# resource "aws_instance" "neb_client" {
#   count                  = var.sleep ? 0 : var.deployervpc_subnet_count
#   instance_type          = "t2.micro"
#   ami                    = data.aws_ami.latest_amazon_linux_2.id
#   subnet_id              = module.vpc.private_subnets[count.index]
#   user_data              = data.template_file.user_data_client.rendered
#   iam_instance_profile   = module.terraform_aws_iam_profile_lighthouse.instance_profile_name
#   vpc_security_group_ids = [module.terraform_aws_sg_bastion.security_group_id]
#   key_name               = "testnebula"

#   user_data_replace_on_change = true
#   root_block_device {
#     delete_on_termination = true
#   }
#   tags = {
#     Name = "client${count.index}"
#   }
# }

# data "template_file" "user_data_client" {
#   template = file("${path.module}/user-data-auth-ssh-host-iam.sh")
#   vars = {
#     resourcetier        = var.resourcetier
#     aws_internal_domain = "${data.aws_region.current.name}.compute.internal"
#     nebula_name         = "client1"
#     aws_region          = data.aws_region.current.name
#     bootstrap_serial    = data.aws_s3_object.nebula_bootstrap.etag
#     lighthouse          = "false"
#   }
# }
