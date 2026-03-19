module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.1.2"

  name = "2048-game-vpc"
  cidr = "10.0.0.0/16"

  azs = ["eu-west-1a", "eu-west-1b"]

  public_subnets = [
    "10.0.1.0/24",
    "10.0.2.0/24"
  ]

  enable_dns_hostnames = true
  enable_dns_support   = true

  enable_nat_gateway = false
  single_nat_gateway = false

  tags = var.tags
}