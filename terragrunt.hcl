include {
  path = find_in_parent_folders()
}

locals {
  common_vars = read_terragrunt_config(find_in_parent_folders("common.hcl"))
}

# TODO remove this hardcoded region
inputs = merge(
  local.common_vars.inputs,
  {
    "region" = "ap-southeast-2"
  }
)

dependencies {
  paths = [
    "../vault",
    # "../vault-configuration",
    "../terraform-aws-sg-vpn"
    ]
}

# skip=true # Currently thre vpn for the main vpc is disabled in favour of deploying the vpn in the render vpc subnet.