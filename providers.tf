terraform {
  # cloud {
  #   organization = "FirehawkVFX"

  #   workspaces {
  #     name = "tf-aws-nebula-test-infra"
  #   }
  # }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.7.0" # 4.7 needed for user_data_replace_on_change
    }
  }

  required_version = ">= 1.2.0, <= 1.5.6"
}

provider "aws" {
  region = var.region

  assume_role {
    # The role ARN within Account to AssumeRole into.
    role_arn = "arn:aws:iam::972620357255:role/circle-ci"
  }

  default_tags {
    tags = {
      # "environment" : get_env("TF_VAR_environment", ""),
      "resourcetier" : var.resourcetier,
      # "conflictkey" : get_env("TF_VAR_conflictkey", ""),
      # "pipelineid" : get_env("TF_VAR_pipelineid", ""),
      # "accountid" : get_env("TF_VAR_account_id", ""),
      # "owner" : get_env("TF_VAR_owner", ""),
      "region" : var.region,
      "vpcname" : lookup(local.common_tags, "vpcname", "default"),
      "projectname" : "tf.aws.firehawk.render",
      "terraform" : "true",
    }
  }
}
