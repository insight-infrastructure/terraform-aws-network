
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

  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = [
    "0.0.0.0/0"]
  }
}

locals {
  prometheus_exporter_ports = [
    9100, # node exporter
    9113, # nginx exporter - TODO: Needs nginx.conf overview
    9115, # blackbox exporter
    8080, # cadvisor
  ]
}

resource "aws_security_group_rule" "prometheus_exporter_rules" {
  count = var.create ? length(local.prometheus_exporter_ports) : 0

  security_group_id = join("", aws_security_group.public.*.id)
  type              = "ingress"

  self        = true
  protocol    = "tcp"
  description = "prometheus exporter port for rule for port ${local.prometheus_exporter_ports[count.index]}"

  from_port = local.prometheus_exporter_ports[count.index]
  to_port   = local.prometheus_exporter_ports[count.index]
}
