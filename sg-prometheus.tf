
variable "enable_prometheus" {
  description = "Enable prometheus monitoring"
  type        = bool
  default     = true
}

resource "aws_security_group" "prometheus" {
  count = var.create ? 1 : 0

  name = "prometheus-${var.id}"
  tags = var.tags

  vpc_id = module.vpc.vpc_id

  dynamic "ingress" {
    for_each = [
      9100, # node exporter
      9113, # nginx exporter - TODO: Needs nginx.conf overview
      9115, # blackbox exporter
      8080, # cadvisor
    ]

    content {
      from_port = ingress.value
      to_port   = ingress.value
      protocol  = "tcp"
      self      = true
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
