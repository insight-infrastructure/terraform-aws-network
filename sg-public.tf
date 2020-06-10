
variable "ingress_tcp_public" {
  description = "List of tcp ports for public ingress"
  type        = list(string)
  default     = [22]
}

variable "ingress_udp_public" {
  description = "List of udp ports for public ingress"
  type        = list(string)
  default     = [22]
}

resource "aws_security_group" "public" {
  count = var.create ? 1 : 0

  name = "public-${var.id}"
  tags = var.tags

  vpc_id = module.vpc.vpc_id

  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }

  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = [
    "0.0.0.0/0"]
  }
}

resource "aws_security_group_rule" "ingress_tcp_rules" {
  count = var.create ? length(var.ingress_tcp_public) : 0

  security_group_id = join("", aws_security_group.public.*.id)
  type              = "ingress"

  cidr_blocks = ["0.0.0.0/0"]
  protocol    = "tcp"
  description = "tcp rule for port ${var.ingress_tcp_public[count.index]}"

  from_port = var.ingress_tcp_public[count.index]
  to_port   = var.ingress_tcp_public[count.index]
}

resource "aws_security_group_rule" "ingress_udp_rules" {
  count = var.create ? length(var.ingress_udp_public) : 0

  security_group_id = join("", aws_security_group.public.*.id)
  type              = "ingress"

  cidr_blocks = ["0.0.0.0/0"]
  protocol    = "udp"
  description = "udp rule for port ${var.ingress_udp_public[count.index]}"

  from_port = var.ingress_udp_public[count.index]
  to_port   = var.ingress_udp_public[count.index]
}
