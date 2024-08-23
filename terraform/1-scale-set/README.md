```hcl
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

  base_cidr    = local.lookup_cidr[var.short][var.env][0]
  subnet_sizes = [26, 26]
}

#module "bastion" {
#  source = "libre-devops/bastion/azurerm"
#
#  rg_name  = data.azurerm_resource_group.rg.name
#  location = data.azurerm_resource_group.rg.location
#  tags     = data.azurerm_resource_group.rg.tags
#
#  bastion_host_name                  = "bst-${var.short}-${var.loc}-${var.env}-01"
#  create_bastion_nsg                 = true
#  create_bastion_nsg_rules           = true
#  create_bastion_subnet              = true
#  bastion_subnet_target_vnet_name    = data.azurerm_virtual_network.vnet.name
#  bastion_subnet_target_vnet_rg_name = data.azurerm_virtual_network.vnet.resource_group_name
#  bastion_subnet_range               = module.subnet_calculator.subnet_ranges[1]
#}

locals {
  name = "vmss${var.short}${var.loc}${var.env}01"
}

module "azdo_spn" {
  source = "github.com/libre-devops/terraform-azuredevops-federated-managed-identity-connection"

  rg_id    = data.azurerm_resource_group.rg.id
  location = data.azurerm_resource_group.rg.location
  tags     = data.azurerm_resource_group.rg.tags

  azuredevops_organization_guid  = data.azurerm_key_vault_secret.azdo_guid.value
  azuredevops_organization_name  = data.azurerm_key_vault_secret.azdo_org_name.value
  azuredevops_project_name       = data.azurerm_key_vault_secret.azdo_project_name.value
  role_definition_name_to_assign = "Contributor"
}


module "windows_vm_scale_set" {
  source = "libre-devops/windows-uniform-orchestration-vm-scale-sets/azurerm"

  rg_name  = data.azurerm_resource_group.rg.name
  location = data.azurerm_resource_group.rg.location
  tags     = data.azurerm_resource_group.rg.tags

  scale_sets = [
    {

      name = local.name

      computer_name_prefix            = "vmss1"
      admin_username                  = "Local${title(var.short)}${title(var.env)}Admin"
      admin_password                  = data.azurerm_key_vault_secret.admin_pwd.value
      instances                       = 1
      sku                             = "Standard_B2ms"
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
          name                          = "nic-${local.name}"
          primary                       = true
          enable_accelerated_networking = false
          ip_configuration = [
            {
              name                           = "ipconfig-${local.name}"
              primary                        = true
              subnet_id                      = data.azurerm_subnet.subnet1.id
              application_security_group_ids = []
            }
          ]
        }
      ]
      os_disk = {
        caching              = "ReadWrite"
        storage_account_type = "StandardSSD_LRS"
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
  name                   = module.windows_vm_scale_set.ss_name[local.name]
  service_endpoint_id    = module.azdo_spn.service_endpoint_id
  service_endpoint_scope = data.azuredevops_project.project.id
  desired_idle           = 1
  max_capacity           = 2
  azure_resource_id      = module.windows_vm_scale_set.ss_id[local.name]
  recycle_after_each_use = false
  time_to_live_minutes   = 30
  agent_interactive_ui   = false
  auto_provision         = true
  auto_update            = true
  project_id             = data.azuredevops_project.project.id
}


```
## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_azuredevops"></a> [azuredevops](#provider\_azuredevops) | 1.0.1 |
| <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) | 3.96.0 |
| <a name="provider_random"></a> [random](#provider\_random) | 3.6.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_azdo_spn"></a> [azdo\_spn](#module\_azdo\_spn) | github.com/libre-devops/terraform-azuredevops-federated-managed-identity-connection | n/a |
| <a name="module_shared_vars"></a> [shared\_vars](#module\_shared\_vars) | libre-devops/shared-vars/azurerm | n/a |
| <a name="module_subnet_calculator"></a> [subnet\_calculator](#module\_subnet\_calculator) | libre-devops/subnet-calculator/null | n/a |
| <a name="module_windows_vm_scale_set"></a> [windows\_vm\_scale\_set](#module\_windows\_vm\_scale\_set) | libre-devops/windows-uniform-orchestration-vm-scale-sets/azurerm | n/a |

## Resources

| Name | Type |
|------|------|
| [azuredevops_elastic_pool.azure_pool](https://registry.terraform.io/providers/microsoft/azuredevops/latest/docs/resources/elastic_pool) | resource |
| [random_string.entropy](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string) | resource |
| [azuredevops_project.project](https://registry.terraform.io/providers/microsoft/azuredevops/latest/docs/data-sources/project) | data source |
| [azurerm_client_config.current_creds](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/client_config) | data source |
| [azurerm_key_vault.mgmt_kv](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/key_vault) | data source |
| [azurerm_key_vault_secret.admin_pwd](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/key_vault_secret) | data source |
| [azurerm_key_vault_secret.azdo_guid](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/key_vault_secret) | data source |
| [azurerm_key_vault_secret.azdo_org_name](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/key_vault_secret) | data source |
| [azurerm_key_vault_secret.azdo_project_name](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/key_vault_secret) | data source |
| [azurerm_resource_group.mgmt_rg](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/resource_group) | data source |
| [azurerm_resource_group.rg](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/resource_group) | data source |
| [azurerm_shared_image.azdo_win_image](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/shared_image) | data source |
| [azurerm_shared_image_gallery.gallery](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/shared_image_gallery) | data source |
| [azurerm_ssh_public_key.mgmt_ssh_key](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/ssh_public_key) | data source |
| [azurerm_subnet.subnet1](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/subnet) | data source |
| [azurerm_user_assigned_identity.mgmt_user_assigned_id](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/user_assigned_identity) | data source |
| [azurerm_user_assigned_identity.uid](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/user_assigned_identity) | data source |
| [azurerm_virtual_network.vnet](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/virtual_network) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_Regions"></a> [Regions](#input\_Regions) | Converts shorthand name to longhand name via lookup on map list | `map(string)` | <pre>{<br>  "eus": "East US",<br>  "euw": "West Europe",<br>  "uks": "UK South",<br>  "ukw": "UK West"<br>}</pre> | no |
| <a name="input_env"></a> [env](#input\_env) | This is passed as an environment variable, it is for the shorthand environment tag for resource.  For example, production = prod | `string` | `"prd"` | no |
| <a name="input_loc"></a> [loc](#input\_loc) | The shorthand name of the Azure location, for example, for UK South, use uks.  For UK West, use ukw. Normally passed as TF\_VAR in pipeline | `string` | `"uks"` | no |
| <a name="input_name"></a> [name](#input\_name) | The name of this resource | `string` | `"tst"` | no |
| <a name="input_short"></a> [short](#input\_short) | This is passed as an environment variable, it is for a shorthand name for the environment, for example hello-world = hw | `string` | `"lbd"` | no |

## Outputs

No outputs.
