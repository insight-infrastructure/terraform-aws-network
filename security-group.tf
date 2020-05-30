
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

resource "aws_security_group" "this" {
  count = var.create ? 1 : 0

  name = var.id
  tags = var.tags

  vpc_id = module.vpc.vpc_id

  dynamic "ingress" {
    for_each = var.ingress_tcp_public

    content {
      from_port = ingress.value
      to_port   = ingress.value
      protocol  = "tcp"
      cidr_blocks = [
      "0.0.0.0/0"]
    }
  }

  dynamic "ingress" {
    for_each = var.ingress_udp_public

    content {
      from_port = ingress.value
      to_port   = ingress.value
      protocol  = "udp"
      cidr_blocks = [
      "0.0.0.0/0"]
    }
  }

  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = [
    "0.0.0.0/0"]
  }
}
