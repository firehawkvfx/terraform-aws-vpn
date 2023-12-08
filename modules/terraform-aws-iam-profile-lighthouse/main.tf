### This role and profile allows instances access to S3 buckets to aquire and push back downloaded softwre to provision with.  It also has prerequisites for consul and Cault IAM access.

resource "aws_iam_role" "instance_role" {
  name               = "lighthouse_instance_role_${var.resourcetier}"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
  tags = {
    "Name" : "lighthouse"
    "role" : "lighthouse"
  }
}
resource "aws_iam_instance_profile" "instance_profile" {
  name = aws_iam_role.instance_role.name
  role = aws_iam_role.instance_role.name
}
data "aws_iam_policy_document" "assume_role" { # Determines the services able to assume the role.  Any entity assuming this role will be able to authenticate to vault.
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}
# Policy to query the identity of the current role.  Required for Vault.
module "iam_policies_get_caller_identity" {
  source      = "github.com/firehawkvfx/firehawk-modules.git//modules/aws-iam-policies-get-caller-identity"
  name        = "STSGetCallerIdentity_${var.resourcetier}"
  iam_role_id = aws_iam_role.instance_role.id
}
# Adds policies necessary for running Consul
module "consul_iam_policies_for_client" {
  source      = "github.com/hashicorp/terraform-aws-consul.git//modules/consul-iam-policies?ref=v0.8.0"
  iam_role_id = aws_iam_role.instance_role.id
}

resource "aws_iam_policy_attachment" "ssm_managed_instance_core" {
  name       = "ssm_managed_instance_core_attachment"
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  roles      = [aws_iam_role.instance_role.name]
}

module "iam_policies_vpn" {
  source       = "github.com/firehawkvfx/firehawk-modules.git//modules/aws-iam-policies-vpn?ref=v0.0.5"
  resourcetier = var.resourcetier
  iam_role_id  = aws_iam_role.instance_role.id
  bucket_arns  = var.bucket_arns
  region       = var.region
}

