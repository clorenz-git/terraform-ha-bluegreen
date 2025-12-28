terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = "ha-bluegreen"
      Env       = var.env
      ManagedBy = "terraform"
    }
  }
}

module "network" {
  source   = "../../modules/network"
  env      = var.env
  vpc_cidr = var.vpc_cidr
  az_count = 2
}

module "ssm_endpoints" {
  source             = "../../modules/ssm_endpoints"
  vpc_id             = module.network.vpc_id
  private_subnet_ids = module.network.private_subnet_ids
  endpoint_sg_id     = module.network.endpoint_sg_id
}

module "compute" {
  source             = "../../modules/compute"
  env                = var.env
  vpc_id             = module.network.vpc_id
  public_subnet_ids  = module.network.public_subnet_ids
  private_subnet_ids = module.network.private_subnet_ids
  alb_sg_id          = module.network.alb_sg_id
  app_sg_id          = module.network.app_sg_id
}
