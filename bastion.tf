variable "enable_bastion" {
  description = "Bool to enable bastion"
  type        = bool
  default     = true
}

data "aws_region" "this" {}

data "template_file" "user_data" {
  template = file("${path.module}/user_data.sh")

  vars = {
    aws_region              = data.aws_region.this
    bucket_name             = var.bucket_name
    extra_user_data_content = var.extra_user_data_content
    allow_ssh_commands      = var.allow_ssh_commands
  }
}

resource "aws_kms_key" "key" {
  tags = merge(var.tags)
}

resource "aws_kms_alias" "alias" {
  name          = "alias/${var.bucket_name}"
  target_key_id = aws_kms_key.key.arn
}

resource "aws_s3_bucket" "bucket" {
  bucket = var.bucket_name
  acl    = "bucket-owner-full-control"

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        kms_master_key_id = aws_kms_key.key.id
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

resource "aws_s3_bucket_object" "bucket_public_keys_readme" {
  bucket     = aws_s3_bucket.bucket.id
  key        = "public-keys/README.txt"
  content    = "Drop here the ssh public keys of the instances you want to control"
  kms_key_id = aws_kms_key.key.arn
}

resource "aws_security_group" "bastion_host_security_group" {
  description = "Enable SSH access to the bastion host from external via SSH port"
  name        = "${local.name_prefix}-host"
  vpc_id      = var.vpc_id

  tags = merge(var.tags)
}

resource "aws_security_group_rule" "ingress_bastion" {
  description = "Incoming traffic to bastion"
  type        = "ingress"
  from_port   = var.public_ssh_port
  to_port     = var.public_ssh_port
  protocol    = "TCP"
  cidr_blocks = concat(data.aws_subnet.subnets.*.cidr_block, var.cidrs)

  security_group_id = aws_security_group.bastion_host_security_group.id
}

resource "aws_security_group_rule" "egress_bastion" {
  description = "Outgoing traffic from bastion to instances"
  type        = "egress"
  from_port   = "0"
  to_port     = "65535"
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = aws_security_group.bastion_host_security_group.id
}

resource "aws_security_group" "private_instances_security_group" {
  description = "Enable SSH access to the Private instances from the bastion via SSH port"
  name        = "${local.name_prefix}-priv-instances"
  vpc_id      = var.vpc_id

  tags = merge(var.tags)
}

resource "aws_security_group_rule" "ingress_instances" {
  description = "Incoming traffic from bastion"
  type        = "ingress"
  from_port   = var.public_ssh_port
  to_port     = var.public_ssh_port
  protocol    = "TCP"

  source_security_group_id = aws_security_group.bastion_host_security_group.id

  security_group_id = aws_security_group.private_instances_security_group.id
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
  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.assume_policy_document.json
}

data "aws_iam_policy_document" "bastion_host_policy_document" {

  statement {
    actions = [
      "s3:PutObject",
      "s3:PutObjectAcl"
    ]
    resources = ["${aws_s3_bucket.bucket.arn}/logs/*"]
  }

  statement {
    actions = [
      "s3:GetObject"
    ]
    resources = ["${aws_s3_bucket.bucket.arn}/public-keys/*"]
  }

  statement {
    actions = [
      "s3:ListBucket"
    ]
    resources = [
    aws_s3_bucket.bucket.arn]

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
    resources = [aws_kms_key.key.arn]
  }

}

resource "aws_iam_policy" "bastion_host_policy" {
  name   = "BastionHost"
  policy = data.aws_iam_policy_document.bastion_host_policy_document.json
}

resource "aws_iam_role_policy_attachment" "bastion_host" {
  policy_arn = aws_iam_policy.bastion_host_policy.arn
  role       = aws_iam_role.bastion_host_role.name
}

resource "aws_route53_record" "bastion_record_name" {
  name    = var.bastion_record_name
  zone_id = var.hosted_zone_id
  type    = "A"
  count   = var.create_dns_record ? 1 : 0

  alias {
    evaluate_target_health = true
    name                   = aws_eip_
    zone_id                = aws_lb.bastion_lb.zone_id
  }
}

resource "aws_eip" "this" {
  tags = var.tags
}

module "ami" {
  source = "github.com/insight-infrastructure/terraform-aws-ami"
}

resource "aws_instance" "this" {
  count         = var.create && var.enable_bastion
  ami           = module.ami.ubuntu_2004_ami_id
  instance_type = var.instance_type
}
