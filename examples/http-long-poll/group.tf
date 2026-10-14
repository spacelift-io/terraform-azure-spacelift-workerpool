resource "random_pet" "this" {}

resource "azurerm_resource_group" "this" {
  name     = "rg-${var.application}-${random_pet.this.id}-${var.env}"
  location = var.location

  tags = local.tags
}
