#####
# sgs
#####
output "sg_public_id" {
  value = join("", aws_security_group.public.*.id)
}

output "sg_bastion_id" {
  value = join("", aws_security_group.bastion.*.id)
}

#########
# Bastion
#########
output "key_names" {
  value = aws_key_pair.bastion.*.key_name
}


#####
# VPC
#####
output "vpc_id" {
  value = module.vpc.vpc_id
}

output "public_subnets" {
  value = module.vpc.public_subnets
}

output "private_subnets" {
  value = module.vpc.private_subnets
}

output "public_subnet_cidr_blocks" {
  value = module.vpc.public_subnets_cidr_blocks
}

output "private_subnets_cidr_blocks" {
  value = module.vpc.private_subnets_cidr_blocks
}

output "azs" {
  value = module.vpc.azs
}

output "private_route_table_ids" {
  value = module.vpc.private_route_table_ids
}
