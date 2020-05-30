# terraform-aws-network

[![open-issues](https://img.shields.io/github/issues-raw/insight-infrastructure/terraform-aws-network?style=for-the-badge)](https://github.com/insight-infrastructure/terraform-aws-network/issues)
[![open-pr](https://img.shields.io/github/issues-pr-raw/insight-infrastructure/terraform-aws-network?style=for-the-badge)](https://github.com/insight-infrastructure/terraform-aws-network/pulls)

## Features

This module deploys a network and security group with dynamic availability zones and a single security group 
that takes a list of ports for both udp and tcp public access. 

## Terraform Versions

For Terraform v0.12.0+

## Usage

```hcl-terraform
resource "random_pet" "this" {
  length = 2
}

module "defaults" {
  source = "../.."
  id     = random_pet.this.id
}
```
## Examples

- [defaults](https://github.com/insight-infrastructure/terraform-aws-network/tree/master/examples/defaults)

## Known  Issues
No issue is creating limit on this module.

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Providers

| Name | Version |
|------|---------|
| aws | n/a |
| template | n/a |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:-----:|
| azs | List of availability zones | `list(string)` | `[]` | no |
| cidr | The cidr range for network | `string` | `"10.0.0.0/16"` | no |
| create | Bool to create | `bool` | `true` | no |
| enable\_bastion | Bool to enable bastion | `bool` | `true` | no |
| id | The id of the resources | `string` | n/a | yes |
| ingress\_tcp\_public | List of tcp ports for public ingress | `list(string)` | <pre>[<br>  22<br>]</pre> | no |
| ingress\_udp\_public | List of udp ports for public ingress | `list(string)` | <pre>[<br>  22<br>]</pre> | no |
| num\_azs | The number of AZs to deploy into | `number` | `3` | no |
| tags | Tags for resources | `map(string)` | `{}` | no |
| vpc\_name | The name of the VPC | `string` | `""` | no |

## Outputs

| Name | Description |
|------|-------------|
| azs | n/a |
| private\_subnets | n/a |
| private\_subnets\_cidr\_blocks | n/a |
| public\_subnet\_cidr\_blocks | n/a |
| public\_subnets | n/a |
| security\_group\_id | #### sgs #### |
| vpc\_id | #### VPC #### |

<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->

## Testing
This module has been packaged with terratest tests

To run them:

1. Install Go
2. Run `make test-init` from the root of this repo
3. Run `make test` again from root

## Authors

Module managed by [insight-infrastructure](https://github.com/insight-infrastructure)

## Credits

- [Anton Babenko](https://github.com/antonbabenko)

## License

Apache 2 Licensed. See LICENSE for full details.