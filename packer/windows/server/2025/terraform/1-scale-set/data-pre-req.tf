data "azurerm_resource_group" "rg" {
  name = "rg-${var.short}-${var.loc}-${var.env}-vmss"
}

data "azurerm_virtual_network" "vnet" {
  name                = "vnet-${var.short}-${var.loc}-${var.env}-vmss-01"
  resource_group_name = data.azurerm_resource_group.rg.name
}

data "azurerm_subnet" "subnet1" {
  name                 = "subnet1"
  resource_group_name  = data.azurerm_virtual_network.vnet.resource_group_name
  virtual_network_name = data.azurerm_virtual_network.vnet.name
}

data "azurerm_shared_image_gallery" "gallery" {
  name                = "gal${var.short}${var.loc}${var.env}vmss01"
  resource_group_name = data.azurerm_resource_group.rg.name
}

data "azurerm_shared_image" "azdo_win_image" {
  gallery_name        = data.azurerm_shared_image_gallery.gallery.name
  name                = "AzDoWindows2022AzureEdition"
  resource_group_name = data.azurerm_shared_image_gallery.gallery.resource_group_name
}

data "azurerm_user_assigned_identity" "uid" {
  name                = "uid-${var.short}-${var.loc}-${var.env}-vmss-01"
  resource_group_name = data.azurerm_resource_group.rg.name
}
