locals {
  rg_name             = "rg-${var.short}-${var.loc}-${var.env}-02"
  vnet_name           = "vnet-${var.short}-${var.loc}-${var.env}-02"
  bastion_name        = "bst-${var.short}-${var.loc}-${var.env}-02"
  bastion_subnet_name = "AzureBastionSubnet"
  vm_subnet_name      = "VMSubnet"
  subnets = {
    (local.bastion_subnet_name) = {
      mask_size = 26
      netnum    = 0
    }
    (local.vm_subnet_name) = {
      mask_size = 26
      netnum    = 1
    }
  }
  nsg_name       = "nsg-${var.short}-${var.loc}-${var.env}-02"
  scale_set_name = "vmss-${var.short}-${var.loc}-${var.env}-02"
  admin_username = "Local${title(var.short)}${title(var.env)}Admin"
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

  base_cidr = local.lookup_cidr[var.short][var.env][0]
  subnets   = local.subnets
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
      address_prefixes = toset([module.subnet_calculator.subnet_ranges[i]])
    }
  }
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
  }
}


module "bastion" {
  source = "libre-devops/bastion/azurerm"

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


module "azdo_spn" {
  source = "github.com/libre-devops/terraform-azuredevops-federated-managed-identity-connection"

  rg_id    = format("/subscriptions/%s/resourceGroups/%s", data.azurerm_client_config.current.subscription_id, local.rg_name)
  location = module.rg.rg_location
  tags     = module.rg.rg_tags

  azuredevops_organization_guid  = data.azurerm_key_vault_secret.azdo_guid.value
  azuredevops_organization_name  = data.azurerm_key_vault_secret.azdo_org_name.value
  azuredevops_project_name       = data.azurerm_key_vault_secret.azdo_project_name.value
  role_definition_name_to_assign = "Contributor"
}

module "linux_vm_scale_set" {
  source = "github.com/libre-devops/terraform-azurerm-linux-uniform-orchestration-vm-scale-set"

  count = var.deploy_windows_vmss ? 0 : 1

  rg_name  = module.rg.rg_name
  location = module.rg.rg_location
  tags     = module.rg.rg_tags

  scale_sets = [
    {

      name = local.scale_set_name

      computer_name_prefix            = "vmss1"
      admin_username                  = local.admin_username
      instances                       = 1
      sku                             = "Standard_D4ds_v5"
      use_simple_image                = false
      use_custom_image                = true
      custom_source_image_id          = data.azurerm_shared_image.azdo_ubuntu_image.id
      disable_password_authentication = true
      overprovision                   = false    # Azure DevOps will set overprovision to false
      upgrade_mode                    = "Manual" # Azure DevOps will set to Manual anyway
      single_placement_group          = false    # Must be disabled for Azure DevOps or will fail
      enable_automatic_updates        = true
      create_asg                      = true
      encryption_at_host_enabled      = true

      admin_ssh_key = [
        {
          username   = local.admin_username
          public_key = data.azurerm_ssh_public_key.mgmt_ssh_key.public_key
        }
      ]

      identity_type = "SystemAssigned, UserAssigned"
      identity_ids  = [module.azdo_spn.user_assigned_managed_identity_id]

      network_interface = [
        {
          name                          = "nic-${local.scale_set_name}"
          primary                       = true
          enable_accelerated_networking = false
          ip_configuration = [
            {
              name                           = "ipconfig-${local.scale_set_name}"
              primary                        = true
              subnet_id                      = module.network.subnets_ids[local.vm_subnet_name]
              application_security_group_ids = []
            }
          ]
        }
      ]
      os_disk = {
        caching              = "ReadOnly"
        storage_account_type = "Premium_LRS"
        disk_size_gb         = 256
      }

      boot_diagnostics = {
        storage_account_uri = null
      }

      extension = []
    }
  ]
}

module "windows_vm_scale_set" {
  source = "libre-devops/windows-uniform-orchestration-vm-scale-sets/azurerm"

  count = var.deploy_windows_vmss ? 1 : 0

  rg_name  = module.rg.rg_name
  location = module.rg.rg_location
  tags     = module.rg.rg_tags

  scale_sets = [
    {

      name = local.scale_set_name

      computer_name_prefix            = "vmss1"
      admin_username                  = local.admin_username
      admin_password                  = data.azurerm_key_vault_secret.admin_pwd.value
      instances                       = 1
      sku                             = "Standard_D4ds_v5"
      vm_os_simple                    = false
      use_custom_image                = true
      custom_source_image_id          = data.azurerm_shared_image.azdo_win_image.id
      disable_password_authentication = true
      overprovision                   = false    # Azure DevOps will set overprovision to false
      upgrade_mode                    = "Manual" # Azure DevOps will set to Manual anyway
      single_placement_group          = false    # Must be disabled for Azure DevOps or will fail
      enable_automatic_updates        = true
      create_asg                      = true

      identity_type = "SystemAssigned, UserAssigned"
      identity_ids  = [module.azdo_spn.user_assigned_managed_identity_id]
      network_interface = [
        {
          name                          = "nic-${local.scale_set_name}"
          primary                       = true
          enable_accelerated_networking = false
          ip_configuration = [
            {
              name                           = "ipconfig-${local.scale_set_name}"
              primary                        = true
              subnet_id                      = module.network.subnets_ids[local.vm_subnet_name]
              application_security_group_ids = []
            }
          ]
        }
      ]
      os_disk = {
        caching              = "ReadOnly"
        storage_account_type = "Premium_LRS"
        disk_size_gb         = 127
      }

      boot_diagnostics = {
        storage_account_uri = null
      }

      extension = []
    }
  ]
}

# This does not install the extension, trying to install the extension manually fails as it needs parameters.
data "azuredevops_project" "project" {
  name = data.azurerm_key_vault_secret.azdo_project_name.value
}

resource "azuredevops_elastic_pool" "azure_pool" {
  name                   = var.deploy_windows_vmss == true ? module.windows_vm_scale_set[0].ss_name[local.scale_set_name] : module.linux_vm_scale_set[0].ss_name[local.scale_set_name]
  service_endpoint_id    = module.azdo_spn.service_endpoint_id
  service_endpoint_scope = data.azuredevops_project.project.id
  desired_idle           = 1
  max_capacity           = 2
  azure_resource_id      = var.deploy_windows_vmss == true ? module.windows_vm_scale_set[0].ss_id[local.scale_set_name] : module.linux_vm_scale_set[0].ss_id[local.scale_set_name]
  recycle_after_each_use = false
  time_to_live_minutes   = 30
  agent_interactive_ui   = false
  auto_provision         = true
  auto_update            = true
  project_id             = data.azuredevops_project.project.id
}

module "role_assignments" {
  source = "github.com/libre-devops/terraform-azurerm-role-assignment"

  role_assignments = [
    {
      principal_ids = var.deploy_windows_vmss == true ? [module.windows_vm_scale_set[0].ss_identity[local.scale_set_name][0].principal_id] : [module.linux_vm_scale_set[0].ss_identity[local.scale_set_name][0].principal_id]
      role_names    = ["Key Vault Administrator", "Contributor"]
      scope         = format("/subscriptions/%s", data.azurerm_client_config.current.subscription_id)
    },
  ]
}
