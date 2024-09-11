module "rg" {
  source = "registry.terraform.io/libre-devops/rg/azurerm"

  rg_name  = "rg-${var.short}-${var.loc}-${var.env}-vmss"
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

resource "azurerm_user_assigned_identity" "uid" {
  name                = "uid-${var.short}-${var.loc}-${var.env}-vmss-01"
  resource_group_name = module.rg.rg_name
  location            = module.rg.rg_location
  tags                = module.rg.rg_tags
}

module "subnet_calculator" {
  source = "libre-devops/subnet-calculator/null"

  base_cidr = local.lookup_cidr[var.short][var.env][0]
  subnets = {
    "AzureBastionSubnet" = {
      mask_size = 26
      netnum    = 0
    }
    "subnet1" = {
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

  vnet_name          = "vnet-${var.short}-${var.loc}-${var.env}-vmss-01"
  vnet_location      = module.rg.rg_location
  vnet_address_space = [module.subnet_calculator.base_cidr]

  subnets = {
    for i, name in module.subnet_calculator.subnet_names :
    name => {
      address_prefixes  = toset([module.subnet_calculator.subnet_ranges[i]])
      service_endpoints = ["Microsoft.KeyVault", "Microsoft.Storage"]
    }
  }
}

module "nsg" {
  source = "libre-devops/nsg/azurerm"

  rg_name  = module.rg.rg_name
  location = module.rg.rg_location
  tags     = module.rg.rg_tags

  nsg_name              = "nsg-${var.short}-${var.loc}-${var.env}-vmss-01"
  associate_with_subnet = true
  subnet_id             = element(values(module.network.subnets_ids), 1)
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
  source = "libre-devops/keyvault/azurerm"

  key_vaults = [
    {
      name     = "kv-${var.short}-${var.loc}-${var.env}-vmss-01"
      rg_name  = module.rg.rg_name
      location = module.rg.rg_location
      tags     = module.rg.rg_tags
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
        virtual_network_subnet_ids = [module.network.subnets_ids["subnet1"]]
      }
    }
  ]
}


module "gallery" {
  source = "registry.terraform.io/libre-devops/compute-gallery/azurerm"

  compute_gallery = [
    {
      name     = "gal${var.short}${var.loc}${var.env}vmss01"
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


  gallery_name = module.gallery.gallery_name["0"]
  images = [
    {
      name                                = "AzDoWindows2022AzureEdition"
      description                         = "Azure DevOps image based on Windows 2022 Azure Edition image"
      specialised                         = false
      hyper_v_generation                  = "V2"
      os_type                             = "Windows"
      accelerated_network_support_enabled = true
      max_recommended_vcpu                = 16
      min_recommended_vcpu                = 2
      max_recommended_memory_in_gb        = 32
      min_recommended_memory_in_gb        = 8

      identifier = {
        offer     = "Azdo${var.short}${var.env}WindowsServer"
        publisher = "LibreDevOps"
        sku       = "AzdoWin2022AzureEdition"
      }
    }
  ]
}

# module "bastion" {
#   source = "libre-devops/bastion/azurerm"
#
#   rg_name  = module.rg.rg_name
#   location = module.rg.rg_location
#   tags     = module.rg.rg_tags
#
#   bastion_host_name                  = "bst-${var.short}-${var.loc}-${var.env}-01"
#   bastion_sku                        = "Developer"
#   create_bastion_nsg                 = true
#   create_bastion_nsg_rules           = true
#   create_bastion_subnet              = false
#   external_subnet_id                 = module.network.subnets_ids["AzureBastionSubnet"]
#   bastion_subnet_target_vnet_name    = module.network.vnet_name
#   bastion_subnet_target_vnet_rg_name = module.network.vnet_rg_name
#   bastion_subnet_range               = "10.0.1.0/27"
# }
#
# resource "azurerm_application_security_group" "server_asg" {
#   resource_group_name = module.rg.rg_name
#   location            = module.rg.rg_location
#   tags                = module.rg.rg_tags
#
#   name = "asg-${var.short}-${var.loc}-${var.env}-01"
# }

# module "windows_server" {
#   source = "github.com/libre-devops/terraform-azurerm-windows-vm"
#
#   rg_name  = module.rg.rg_name
#   location = module.rg.rg_location
#   tags     = module.rg.rg_tags
#
#   windows_vms = [
#     {
#       name           = "app-${var.short}-${var.loc}-${var.env}-01"
#       subnet_id      = module.network.subnets_ids["subnet1"]
#       create_asg     = true
#       admin_username = "Local${title(var.short)}${title(var.env)}Admin"
#       admin_password = data.azurerm_key_vault_secret.admin_pwd.value
#       vm_size        = "Standard_B2ms"
#       timezone       = "UTC"
#       vm_os_simple   = "WindowsServer2022AzureEditionGen2"
#       os_disk = {
#         disk_size_gb = 128
#       }
#       run_vm_command = {
#         inline = "try { Install-WindowsFeature -Name FS-FileServer -IncludeManagementTools } catch { Write-Error 'Failed to install File Services: $_'; exit 1 }"
#       }
#     },
#   ]
# }