variable "enable_bastion" {
  description = "Bool to enable bastion"
  type        = bool
  default     = true
}

variable "instance_type" {
  description = "The instance type of the bastion instances."
  type        = string
  default     = "t2.nano"
}

variable "bastion_monitoring_enabled" {
  description = "Cloudwatch monitoring on bastion"
  type        = bool
  default     = true
}

variable "public_key_paths" {
  description = "List of paths to public ssh keys"
  type        = list(string)
  default     = []
}

####
# S3
####
variable "bucket_name" {
  description = "Bucket name were the bastion will store the logs"
  type        = string
  default     = ""
}

variable "bucket_versioning" {
  default     = true
  description = "Enable bucket versioning or not"
}

variable "bucket_force_destroy" {
  default     = false
  type        = bool
  description = "The bucket and all objects should be destroyed when using true"
}


variable "extra_user_data_content" {
  description = "Additional scripting to pass to the bastion host. For example, this can include installing postgresql for the `psql` command."
  type        = string
  default     = ""
}

variable "allow_ssh_commands" {
  description = "Allows the SSH user to execute one-off commands. Pass 'True' to enable. Warning: These commands are not logged and increase the vulnerability of the system. Use at your own discretion."
  type        = string
  default     = ""
}

######
# Logs
######
variable "log_auto_clean" {
  description = "Enable or not the lifecycle"
  default     = false
  type        = bool
}

variable "log_standard_ia_days" {
  description = "Number of days before moving logs to IA Storage"
  type        = number
  default     = 30
}

variable "log_glacier_days" {
  description = "Number of days before moving logs to Glacier"
  type        = number
  default     = 60
}

variable "log_expiry_days" {
  description = "Number of days before logs expiration"
  default     = 90
  type        = number
}

variable "public_ssh_port" {
  description = "Set the SSH port to use from desktop to the bastion"
  default     = 22
  type        = number
}

#####
# DNS
#####
variable "domain_name" {
  description = ""
  type        = string
  default     = ""
}

variable "bastion_host_name" {
  description = "The hostname for bastion"
  type        = string
  default     = "bastion"
}

data "aws_region" "this" {}
data "aws_caller_identity" "this" {}

locals {
  bucket_name = var.bucket_name == "" ? "logs-${data.aws_caller_identity.this.account_id}" : var.bucket_name
}

data "template_file" "user_data" {
  template = file("${path.module}/bastion-user-data.sh")

  vars = {
    aws_region              = data.aws_region.this.name
    bucket_name             = local.bucket_name
    extra_user_data_content = var.extra_user_data_content
    allow_ssh_commands      = var.allow_ssh_commands
  }
}

resource "aws_kms_key" "key" {
  count = var.create && var.enable_bastion ? 1 : 0
  tags  = merge(var.tags)
}

resource "aws_kms_alias" "alias" {
  count         = var.create && var.enable_bastion ? 1 : 0
  name          = "alias/${local.bucket_name}"
  target_key_id = join("", aws_kms_key.key.*.arn)
}

resource "aws_s3_bucket" "bucket" {
  count = var.create && var.enable_bastion ? 1 : 0

  bucket = local.bucket_name
  acl    = "bucket-owner-full-control"

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        kms_master_key_id = join("", aws_kms_key.key.*.id)
        sse_algorithm     = "aws:kms"
      }
    }
  }


  force_destroy = var.bucket_force_destroy

  versioning {
    enabled = var.bucket_versioning
  }

  lifecycle_rule {
    id      = "log"
    enabled = var.log_auto_clean

    prefix = "logs/"

    tags = {
      rule      = "log"
      autoclean = var.log_auto_clean
    }

    transition {
      days          = var.log_standard_ia_days
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = var.log_glacier_days
      storage_class = "GLACIER"
    }

    expiration {
      days = var.log_expiry_days
    }
  }

  tags = merge(var.tags)
}

resource "aws_s3_bucket_object" "keys_readme" {
  count = var.create && var.enable_bastion ? 1 : 0

  bucket     = join("", aws_s3_bucket.bucket.*.id)
  key        = "public-keys/README.txt"
  content    = "Drop here the ssh public keys of the instances you want to control"
  kms_key_id = join("", aws_kms_key.key.*.arn)
}

resource "aws_s3_bucket_object" "keys_uploads" {
  count = var.create && var.enable_bastion ? length(var.public_key_paths) : 0

  bucket     = join("", aws_s3_bucket.bucket.*.id)
  key        = "public-keys/${basename(var.public_key_paths[count.index])}"
  content    = file(var.public_key_paths[count.index])
  kms_key_id = join("", aws_kms_key.key.*.arn)
}

resource "aws_security_group" "bastion" {
  count = var.create && var.enable_bastion ? 1 : 0

  description = "Enable SSH access to the bastion host from external via SSH port"
  name        = "bation-${var.id}"
  vpc_id      = module.vpc.vpc_id

  tags = var.tags
}

data "aws_iam_policy_document" "assume_policy_document" {
  statement {
    actions = [
      "sts:AssumeRole"
    ]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "bastion_host_role" {
  count = var.create && var.enable_bastion ? 1 : 0

  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.assume_policy_document.json
}

data "aws_iam_policy_document" "bastion_host_policy_document" {

  statement {
    actions = [
      "s3:PutObject",
      "s3:PutObjectAcl"
    ]
    resources = ["${join("", aws_s3_bucket.bucket.*.arn)}/logs/*"]
  }

  statement {
    actions = [
      "s3:GetObject"
    ]
    resources = ["${join("", aws_s3_bucket.bucket.*.arn)}/public-keys/*"]
  }

  statement {
    actions = [
      "s3:ListBucket"
    ]
    resources = [
    join("", aws_s3_bucket.bucket.*.arn)]

    condition {
      test     = "ForAnyValue:StringEquals"
      values   = ["public-keys/"]
      variable = "s3:prefix"
    }
  }

  statement {
    actions = [
      "kms:Encrypt",
      "kms:Decrypt"
    ]
    resources = [join("", aws_kms_key.key.*.arn)]
  }

}

resource "aws_iam_policy" "bastion_host_policy" {
  count = var.create && var.enable_bastion ? 1 : 0

  name   = "BastionHostS3Read${replace(title(replace(var.id, "-", " ")), " ", "")}Policy"
  policy = data.aws_iam_policy_document.bastion_host_policy_document.json
}

resource "aws_iam_role_policy_attachment" "bastion_host" {
  count = var.create && var.enable_bastion ? 1 : 0

  policy_arn = join("", aws_iam_policy.bastion_host_policy.*.arn)
  role       = join("", aws_iam_role.bastion_host_role.*.name)
}

locals {
  bastion_dns_record = "${var.bastion_host_name}.${var.domain_name}"
}

resource "aws_route53_record" "bastion_record_name" {
  count = var.domain_name != "" && var.create && var.enable_bastion ? 1 : 0

  name    = local.bastion_dns_record
  zone_id = join("", data.aws_route53_zone.this.*.id)
  type    = "A"
  ttl     = 300
  records = [join("", aws_eip.bastion.*.public_ip)]
}

resource "aws_eip" "bastion" {
  count = var.create && var.enable_bastion ? 1 : 0
  tags  = var.tags
}

module "ami" {
  source = "github.com/insight-infrastructure/terraform-aws-ami.git"
}

resource "aws_key_pair" "bastion" {
  count      = length(var.public_key_paths)
  public_key = file(var.public_key_paths[count.index])
  key_name   = basename(var.public_key_paths[count.index])
  tags       = merge(var.tags, { name = basename(var.public_key_paths[count.index]) })
}

resource "aws_instance" "this" {
  count = var.create && var.enable_bastion ? 1 : 0

  ami                    = module.ami.ubuntu_2004_ami_id
  instance_type          = var.instance_type
  user_data              = data.template_file.user_data.rendered
  subnet_id              = module.vpc.public_subnets[0]
  vpc_security_group_ids = [join("", aws_security_group.public.*.id)]
  monitoring             = var.bastion_monitoring_enabled

  tags = merge({ name = "bastion" }, var.tags)
}

