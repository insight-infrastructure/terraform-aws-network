
resource "random_pet" "this" {
  length = 2
}

module "defaults" {
  source = "../.."
  id     = random_pet.this.id
}
