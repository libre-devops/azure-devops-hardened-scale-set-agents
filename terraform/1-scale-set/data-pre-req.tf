data "azurerm_resource_group" "rg" {
  name = "rg-${var.short}-${var.loc}-${var.env}-01"
}

data "azurerm_virtual_network" "vnet" {
  name                = "vnet-${var.short}-${var.loc}-${var.env}-01"
  resource_group_name = data.azurerm_resource_group.rg.name
}

data "azurerm_shared_image_gallery" "gallery" {
  name                = "gal${var.short}${var.loc}${var.env}01"
  resource_group_name = data.azurerm_resource_group.rg.name
}

data "azurerm_shared_image" "azdo_win_image" {
  gallery_name        = data.azurerm_shared_image_gallery.gallery.name
  name                = "AzDoWindows2025"
  resource_group_name = data.azurerm_shared_image_gallery.gallery.resource_group_name
}

data "azurerm_shared_image" "azdo_ubuntu_image" {
  gallery_name        = data.azurerm_shared_image_gallery.gallery.name
  name                = "AzDoUbuntu2404"
  resource_group_name = data.azurerm_shared_image_gallery.gallery.resource_group_name
}
