variable "aws_region" {
  default = "us-east-1"
}

provider "aws" {
  region = var.aws_region
}

resource "random_pet" "this" {
  length = 2
}

module "defaults" {
  source = "../.."
  id     = random_pet.this.id

  ingress_tcp_public = [22, 80, 443]
}

module "ami" {
  source = "github.com/insight-infrastructure/terraform-aws-ami"
}

resource "aws_instance" "this" {
  ami                    = module.ami.ubuntu_2004_ami_id
  instance_type          = "t2.micro"
  vpc_security_group_ids = [module.defaults.sg_public_id]
  subnet_id              = module.defaults.public_subnets[0]
}