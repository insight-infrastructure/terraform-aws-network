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
  public_key_paths = [
    "${path.cwd}/test1.pub",
    "${path.cwd}/test2.pub"
  ]
}

