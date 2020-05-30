data "aws_route53_zone" "this" {
  count = var.domain_name == "" ? 0 : 1
  name  = "${var.domain_name}."
}
