locals {
  rg_name             = "rg-${var.short}-${var.loc}-${var.env}-01"
  vnet_name           = "vnet-${var.short}-${var.loc}-${var.env}-01"
  vm_subnet_name      = "VMsubnet"
  bastion_name        = "bst-${var.short}-${var.loc}-${var.env}-01"
  bastion_subnet_name = "AzureBastionSubnet"
  nsg_name            = "nsg-${var.short}-${var.loc}-${var.env}-01"
  uid_name            = "uid-${var.short}-${var.loc}-${var.env}-01"
  key_vault_name      = "kv-${var.short}-${var.loc}-${var.env}-01"
  gallery_name        = "gal${var.short}${var.loc}${var.env}01"
  windows_image_name  = "AzDoWindows2025"
  ubuntu_image_name   = "AzdoUbuntu2404"
}

module "rg" {
  source = "libre-devops/rg/azurerm"

  rg_name  = local.rg_name
  location = local.location
  tags     = local.tags
}

module "shared_vars" {
  source = "libre-devops/shared-vars/azurerm"
}

locals {
  lookup_cidr = {
    for landing_zone, envs in module.shared_vars.cidrs : landing_zone => {
      for env, cidr in envs : env => cidr
    }
  }
}

module "subnet_calculator" {
  source = "libre-devops/subnet-calculator/null"

  base_cidr = local.lookup_cidr["lbd"][var.env][0]
  subnets = {
    (local.vm_subnet_name) = {
      mask_size = 26
      netnum    = 0
    }
    (local.bastion_subnet_name) = {
      mask_size = 26
      netnum    = 1
    }
  }
}

module "network" {
  source = "libre-devops/network/azurerm"

  rg_name  = module.rg.rg_name
  location = module.rg.rg_location
  tags     = module.rg.rg_tags

  vnet_name          = local.vnet_name
  vnet_location      = module.rg.rg_location
  vnet_address_space = [module.subnet_calculator.base_cidr]

  subnets = {
    for i, name in module.subnet_calculator.subnet_names :
    name => {
      address_prefixes  = toset([module.subnet_calculator.subnet_ranges[i]])
      service_endpoints = name == local.vm_subnet_name ? ["Microsoft.KeyVault"] : []

      # Only assign delegation to subnet3
      delegation = []
    }
  }
}

module "bastion" {
  source = "libre-devops/bastion/azurerm"

  count = var.deploy_bastion == true ? 1 : 0

  rg_name  = module.rg.rg_name
  location = module.rg.rg_location
  tags     = module.rg.rg_tags

  bastion_host_name        = local.bastion_name
  bastion_sku              = "Basic"
  virtual_network_id       = module.network.vnet_id
  create_bastion_nsg       = true
  create_bastion_nsg_rules = true
  create_bastion_subnet    = false
  external_subnet_id       = module.network.subnets_ids[local.bastion_subnet_name]
}



module "nsg" {
  source = "libre-devops/nsg/azurerm"

  rg_name  = module.rg.rg_name
  location = module.rg.rg_location
  tags     = module.rg.rg_tags

  nsg_name              = local.nsg_name
  associate_with_subnet = true
  subnet_id             = module.network.subnets_ids[local.vm_subnet_name]
  custom_nsg_rules = {
    "AllowVnetInbound" = {
      priority                   = 100
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "*"
      source_address_prefix      = "VirtualNetwork"
      destination_address_prefix = "VirtualNetwork"
    }
    "AllowClientInbound" = {
      priority                   = 101
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "*"
      source_address_prefix      = chomp(data.http.user_ip.response_body)
      destination_address_prefix = "VirtualNetwork"
    }
  }
}

data "http" "user_ip" {
  url = "https://checkip.amazonaws.com"
}

resource "azurerm_user_assigned_identity" "uid" {
  resource_group_name = module.rg.rg_name
  location            = module.rg.rg_location
  tags                = module.rg.rg_tags

  name = local.uid_name
}

module "role_assignments" {
  source = "github.com/libre-devops/terraform-azurerm-role-assignment"

  role_assignments = [
    {
      principal_ids = [data.azurerm_client_config.current.object_id]
      role_names    = ["Key Vault Administrator"]
      scope         = module.rg.rg_id
      set_condition = true
    },
    {
      principal_ids = [azurerm_user_assigned_identity.uid.principal_id]
      role_names    = ["Key Vault Administrator"]
      scope         = module.rg.rg_id
      set_condition = true
    }
  ]
}


module "key_vault" {
  source = "github.com/libre-devops/terraform-azurerm-keyvault"

  key_vaults = [
    {
      name                            = local.key_vault_name
      rg_name                         = module.rg.rg_name
      location                        = module.rg.rg_location
      tags                            = module.rg.rg_tags
      enabled_for_deployment          = true
      enabled_for_disk_encryption     = true
      enabled_for_template_deployment = true
      enable_rbac_authorization       = true
      purge_protection_enabled        = false
      public_network_access_enabled   = true
      network_acls = {
        default_action             = "Deny"
        bypass                     = "AzureServices"
        ip_rules                   = [chomp(data.http.user_ip.response_body)]
        virtual_network_subnet_ids = [module.network.subnets_ids[local.vm_subnet_name]]
      }
    }
  ]
}


module "gallery" {
  source = "registry.terraform.io/libre-devops/compute-gallery/azurerm"

  compute_gallery = [
    {
      name     = local.gallery_name
      rg_name  = module.rg.rg_name
      location = module.rg.rg_location
      tags     = module.rg.rg_tags
    }
  ]
}

module "images" {
  source = "registry.terraform.io/libre-devops/compute-gallery-image/azurerm"

  rg_name  = module.rg.rg_name
  location = module.rg.rg_location
  tags     = module.rg.rg_tags


  gallery_name = module.gallery.gallery_name[local.gallery_name]
  images = [
    {
      name                                = local.windows_image_name
      description                         = "Azure DevOps image based on Windows 2025"
      specialised                         = false
      hyper_v_generation                  = "V2"
      os_type                             = "Windows"
      accelerated_network_support_enabled = true
      max_recommended_vcpu                = 16
      min_recommended_vcpu                = 2
      max_recommended_memory_in_gb        = 32
      min_recommended_memory_in_gb        = 8

      identifier = {
        offer     = "AzdoWindowsServer"
        publisher = "LibreDevOps"
        sku       = local.windows_image_name
      }
    },
    {
      name                                = local.ubuntu_image_name
      description                         = "Azure DevOps image based on Ubuntu 24.04"
      specialised                         = false
      hyper_v_generation                  = "V2"
      os_type                             = "Linux"
      accelerated_network_support_enabled = true
      max_recommended_vcpu                = 16
      min_recommended_vcpu                = 2
      max_recommended_memory_in_gb        = 32
      min_recommended_memory_in_gb        = 8

      identifier = {
        offer     = "AzdoUbuntuServer"
        publisher = "LibreDevOps"
        sku       = local.ubuntu_image_name
      }
    }
  ]
}
