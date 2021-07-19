# The public IP you connect to your Bastion host via
resource "azurerm_public_ip" "bastion" {
  name                = "ip-bastion-${local.namespace}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = local.tags
}

# The Bastion host
resource "azurerm_bastion_host" "this" {
  name                = "bas-${local.namespace}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name

  ip_configuration {
    name                 = "public-access"
    subnet_id            = azurerm_subnet.bastion.id
    public_ip_address_id = azurerm_public_ip.bastion.id
  }

  tags = local.tags
}
