//variable "enable_bastion" {
//  description = "Bool to enable bastion"
//  type        = bool
//  default     = true
//}
//
//variable "instance_type" {
//  description = "The instance type of the bastion instances."
//  type = string
//  default = "t2.nano"
//}
//
//####
//# S3
//####
//variable "bucket_name" {
//  description = "Bucket name were the bastion will store the logs"
//  type = string
//  default = ""
//}
//
//variable "bucket_versioning" {
//  default     = true
//  description = "Enable bucket versioning or not"
//}
//
//variable "bucket_force_destroy" {
//  default     = false
//  type = bool
//  description = "The bucket and all objects should be destroyed when using true"
//}
//
//
//variable "extra_user_data_content" {
//  description = "Additional scripting to pass to the bastion host. For example, this can include installing postgresql for the `psql` command."
//  type        = string
//  default     = ""
//}
//
//variable "allow_ssh_commands" {
//  description = "Allows the SSH user to execute one-off commands. Pass 'True' to enable. Warning: These commands are not logged and increase the vulnerability of the system. Use at your own discretion."
//  type        = string
//  default     = ""
//}
//
//######
//# Logs
//######
//variable "log_auto_clean" {
//  description = "Enable or not the lifecycle"
//  default     = false
//  type = bool
//}
//
//variable "log_standard_ia_days" {
//  description = "Number of days before moving logs to IA Storage"
//  type = number
//  default     = 30
//}
//
//variable "log_glacier_days" {
//  description = "Number of days before moving logs to Glacier"
//  type = number
//  default     = 60
//}
//
//variable "log_expiry_days" {
//  description = "Number of days before logs expiration"
//  default     = 90
//  type = number
//}
//
//variable "public_ssh_port" {
//  description = "Set the SSH port to use from desktop to the bastion"
//  default     = 22
//  type = number
//}
//
//#####
//# DNS
//#####
//variable "root_domain" {
//  description = ""
//}
//
//data "aws_region" "this" {}
//data "aws_caller_identity" "this" {}
//
//locals {
//  bucket_name = var.bucket_name == "" ? "logs-${data.aws_caller_identity.this}" : var.bucket_name
//}
//
//data "template_file" "user_data" {
//  template = file("${path.module}/user_data.sh")
//
//  vars = {
//    aws_region              = data.aws_region.this
//    bucket_name             = local.bucket_name
//    extra_user_data_content = var.extra_user_data_content
//    allow_ssh_commands      = var.allow_ssh_commands
//  }
//}
//
//resource "aws_kms_key" "key" {
//  tags = merge(var.tags)
//}
//
//resource "aws_kms_alias" "alias" {
//  name          = "alias/${local.bucket_name}"
//  target_key_id = aws_kms_key.key.arn
//}
//
//resource "aws_s3_bucket" "bucket" {
//  bucket = local.bucket_name
//  acl    = "bucket-owner-full-control"
//
//  server_side_encryption_configuration {
//    rule {
//      apply_server_side_encryption_by_default {
//        kms_master_key_id = aws_kms_key.key.id
//        sse_algorithm     = "aws:kms"
//      }
//    }
//  }
//
//
//  force_destroy = var.bucket_force_destroy
//
//  versioning {
//    enabled = var.bucket_versioning
//  }
//
//  lifecycle_rule {
//    id      = "log"
//    enabled = var.log_auto_clean
//
//    prefix = "logs/"
//
//    tags = {
//      rule      = "log"
//      autoclean = var.log_auto_clean
//    }
//
//    transition {
//      days          = var.log_standard_ia_days
//      storage_class = "STANDARD_IA"
//    }
//
//    transition {
//      days          = var.log_glacier_days
//      storage_class = "GLACIER"
//    }
//
//    expiration {
//      days = var.log_expiry_days
//    }
//  }
//
//  tags = merge(var.tags)
//}
//
//resource "aws_s3_bucket_object" "bucket_public_keys_readme" {
//  bucket     = aws_s3_bucket.bucket.id
//  key        = "public-keys/README.txt"
//  content    = "Drop here the ssh public keys of the instances you want to control"
//  kms_key_id = aws_kms_key.key.arn
//}
//
//resource "aws_security_group" "bastion_host_security_group" {
//  description = "Enable SSH access to the bastion host from external via SSH port"
//  name        = "${local.name_prefix}-host"
//  vpc_id      = module.vpc.vpc_id
//
//  tags = merge(var.tags)
//}
//
//resource "aws_security_group_rule" "ingress_bastion" {
//  description = "Incoming traffic to bastion"
//  type        = "ingress"
//  from_port   = var.public_ssh_port
//  to_port     = var.public_ssh_port
//  protocol    = "TCP"
//  cidr_blocks = concat(data.aws_subnet.subnets.*.cidr_block, var.cidrs)
//
//  security_group_id = aws_security_group.bastion_host_security_group.id
//}
//
//resource "aws_security_group" "private_instances_security_group" {
//  description = "Enable SSH access to the Private instances from the bastion via SSH port"
//  name        = "${local.name_prefix}-priv-instances"
//  vpc_id      = module.vpc.vpc_id
//
//  egress {
//    from_port = 0
//    to_port   = 0
//    protocol  = "-1"
//    cidr_blocks = [
//      "0.0.0.0/0"]
//  }
//
//  tags = var.tags
//}
//
//resource "aws_security_group_rule" "ingress_instances" {
//  description = "Incoming traffic from bastion"
//  type        = "ingress"
//  from_port   = var.public_ssh_port
//  to_port     = var.public_ssh_port
//  protocol    = "TCP"
//
//  source_security_group_id = aws_security_group.bastion_host_security_group.id
//
//  security_group_id = aws_security_group.private_instances_security_group.id
//}
//
//data "aws_iam_policy_document" "assume_policy_document" {
//  statement {
//    actions = [
//      "sts:AssumeRole"
//    ]
//    principals {
//      type        = "Service"
//      identifiers = ["ec2.amazonaws.com"]
//    }
//  }
//}
//
//resource "aws_iam_role" "bastion_host_role" {
//  path               = "/"
//  assume_role_policy = data.aws_iam_policy_document.assume_policy_document.json
//}
//
//data "aws_iam_policy_document" "bastion_host_policy_document" {
//
//  statement {
//    actions = [
//      "s3:PutObject",
//      "s3:PutObjectAcl"
//    ]
//    resources = ["${aws_s3_bucket.bucket.arn}/logs/*"]
//  }
//
//  statement {
//    actions = [
//      "s3:GetObject"
//    ]
//    resources = ["${aws_s3_bucket.bucket.arn}/public-keys/*"]
//  }
//
//  statement {
//    actions = [
//      "s3:ListBucket"
//    ]
//    resources = [
//    aws_s3_bucket.bucket.arn]
//
//    condition {
//      test     = "ForAnyValue:StringEquals"
//      values   = ["public-keys/"]
//      variable = "s3:prefix"
//    }
//  }
//
//  statement {
//    actions = [
//      "kms:Encrypt",
//      "kms:Decrypt"
//    ]
//    resources = [aws_kms_key.key.arn]
//  }
//
//}
//
//resource "aws_iam_policy" "bastion_host_policy" {
//  name   = "BastionHost"
//  policy = data.aws_iam_policy_document.bastion_host_policy_document.json
//}
//
//resource "aws_iam_role_policy_attachment" "bastion_host" {
//  policy_arn = aws_iam_policy.bastion_host_policy.arn
//  role       = aws_iam_role.bastion_host_role.name
//}
//
//data "aws_route53_zone" "this" {
//  count = var.domain_name == "" ? 0 : 1
//  name  = "${var.domain_name}."
//}
//
////resource "aws_route53_record" "bastion_record_name" {
////  count   = var.create_dns_record ? 1 : 0
////
////  name    = var.bastion_record_name
////  zone_id = var.hosted_zone_id
////  type    = "A"
////}
//
//resource "aws_eip" "this" {
//  tags = var.tags
//}
//
//module "ami" {
//  source = "github.com/insight-infrastructure/terraform-aws-ami"
//}
//
//resource "aws_instance" "this" {
//  count         = var.create && var.enable_bastion ? 1 : 0
//  ami           = module.ami.ubuntu_2004_ami_id
//  instance_type = var.instance_type
//}
