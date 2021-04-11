provider "null" {
  version = "~> 3.0"
}

provider "aws" {
  #  if you haven't installed and configured the aws cli, you will need to provide your aws access key and secret key.
  # in a dev environment these version locks below can be disabled.  in production, they should be locked based on the suggested versions from terraform init.
  version = "~> 3.15.0"
}

data "aws_region" "current" {}

locals {
  common_tags = var.common_tags
}

data "aws_vpc" "primary" {
  default = false
  tags    = local.common_tags
}
data "aws_internet_gateway" "gw" {
  # default = false
  tags = local.common_tags
}

data "aws_subnet_ids" "public" {
  vpc_id = data.aws_vpc.primary.id
  tags   = merge(local.common_tags, { "area" : "public" })
}

data "aws_subnet" "public" {
  for_each = data.aws_subnet_ids.public.ids
  id       = each.value
}

data "aws_subnet_ids" "private" {
  vpc_id = data.aws_vpc.primary.id
  tags   = merge(local.common_tags, { "area" : "private" })
}

data "aws_subnet" "private" {
  for_each = data.aws_subnet_ids.private.ids
  id       = each.value
}

data "aws_route_tables" "public" {
  vpc_id = data.aws_vpc.primary.id
  tags   = merge(local.common_tags, { "area" : "public" })
}

data "aws_route_tables" "private" {
  vpc_id = data.aws_vpc.primary.id
  tags   = merge(local.common_tags, { "area" : "private" })
}

locals {
  mount_path                 = var.resourcetier
  vpc_id                     = data.aws_vpc.primary.id
  vpc_cidr                   = data.aws_vpc.primary.cidr_block
  aws_internet_gateway       = data.aws_internet_gateway.gw.id
  public_subnets             = sort(data.aws_subnet_ids.public.ids)
  public_subnet_cidr_blocks  = [for s in data.aws_subnet.public : s.cidr_block]
  private_subnets            = sort(data.aws_subnet_ids.private.ids)
  private_subnet_cidr_blocks = [for s in data.aws_subnet.private : s.cidr_block]
  vpn_cidr                   = var.vpn_cidr
  onsite_private_subnet_cidr = var.onsite_private_subnet_cidr
  onsite_public_ip           = var.onsite_public_ip
  private_route_table_ids    = sort(data.aws_route_tables.private.ids)
  public_route_table_ids     = sort(data.aws_route_tables.public.ids)
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
data "terraform_remote_state" "vpn_security_group" { # read the arn with data.terraform_remote_state.packer_profile.outputs.instance_role_arn, or read the profile name with data.terraform_remote_state.packer_profile.outputs.instance_profile_name
  backend = "s3"
  config = {
    bucket = "state.terraform.${var.bucket_extension_vault}"
    key    = "firehawk-main/modules/terraform-aws-sg-vpn/terraform.tfstate"
    region = data.aws_region.current.name
  }
}

module "vpn" {
  source                     = "./modules/tf_aws_openvpn"
  create_vpn                 = true
  security_group_attachments = [data.terraform_remote_state.vpn_security_group.outputs.security_group_id]
  example_role_name          = "vpn-server-vault-role" # this authenticates with a dynamically generated secret key
  name                       = local.instance_name
  ami                        = var.openvpn_server_ami
  iam_instance_profile_name  = data.terraform_remote_state.openvpn_profile.outputs.instance_profile_name
  resourcetier               = var.resourcetier
  conflictkey                = var.conflictkey
  # VPC Inputs
  vpc_id                     = local.vpc_id
  vpc_cidr                   = local.vpc_cidr
  vpn_cidr                   = local.vpn_cidr
  combined_vpcs_cidr         = var.combined_vpcs_cidr
  public_subnet_ids          = local.public_subnets
  remote_vpn_ip_cidr         = "${local.onsite_public_ip}/32"
  remote_ssh_ip_cidr         = var.deployer_ip_cidr # This may be the same as above, but can be different if using cloud 9 for deployment
  onsite_private_subnet_cidr = local.onsite_private_subnet_cidr
  private_route_table_ids    = local.private_route_table_ids
  public_route_table_ids     = local.public_route_table_ids
  route_public_domain_name   = var.route_public_domain_name
  igw_id                     = local.aws_internet_gateway
  public_subnets             = local.public_subnet_cidr_blocks
  private_subnets            = local.private_subnet_cidr_blocks
  # EC2 Inputs
  aws_key_name  = var.aws_key_name # This should be replaced with an admin level ssh cert.
  instance_type = var.instance_type
  # Network Routing Inputs.  source destination checks are disable for nat gateways or routing on an instance.
  source_dest_check = false
  # DNS Inputs
  consul_cluster_name    = var.consul_cluster_name
  consul_cluster_tag_key = var.consul_cluster_tag_key
  public_domain_name     = local.public_domain_name
  # private_domain_name    = local.private_domain # removed this becuase of ref to vault secret - cannot destroy.
  # private_domain_name = "consul"
  route_zone_id = local.route_zone_id
  # # OpenVPN Inputs
  openvpn_user       = "openvpnas"
  openvpn_admin_user = "openvpnas"
  # bastion_ip               = module.bastion.public_ip # the vpn is provisioned by the bastion entry point
  # bastion_dependency       = module.bastion.bastion_dependency
  # firehawk_init_dependency = var.firehawk_init_dependency
  #sleep will stop instances to save cost during idle time.
  sleep       = var.sleep
  common_tags = local.common_tags
}
