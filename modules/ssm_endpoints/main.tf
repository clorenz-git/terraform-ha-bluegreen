data "aws_region" "current" {}

# SSM requires these three interface endpoints for private subnets (no NAT)
locals {
  services = [
    "ssm",
    "ec2messages",
    "ssmmessages",
  ]
}

resource "aws_vpc_endpoint" "this" {
  for_each = toset(local.services)

  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.${each.value}"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids         = var.private_subnet_ids
  security_group_ids = [var.endpoint_sg_id]

  tags = {
    Name = "vpce-${each.value}"
  }
}
