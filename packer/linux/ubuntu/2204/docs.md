## Requirements

No requirements.

## Providers

No providers.

## Modules

No modules.

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_client_id"></a> [client\_id](#input\_client\_id) | The client id, passed as a PKR\_VAR | `string` | `"PKR_VAR_client_id"` | no |
| <a name="input_client_secret"></a> [client\_secret](#input\_client\_secret) | The client\_secret, passed as a PKR\_VAR | `string` | `"PKR_VAR_client_secret"` | no |
| <a name="input_dockerhub_login"></a> [dockerhub\_login](#input\_dockerhub\_login) | The docker hub login, passed as a PKR\_VAR | `string` | `"PKR_VAR_dockerhub_login"` | no |
| <a name="input_dockerhub_password"></a> [dockerhub\_password](#input\_dockerhub\_password) | The docker hub password passed as a PKR\_VAR | `string` | `"PKR_VAR_dockerhub_password"` | no |
| <a name="input_gallery_name"></a> [gallery\_name](#input\_gallery\_name) | The gallery name | `string` | `"galldoeuwdev01"` | no |
| <a name="input_gallery_rg_name"></a> [gallery\_rg\_name](#input\_gallery\_rg\_name) | The gallery resource group name | `string` | `"rg-ldo-euw-dev-build"` | no |
| <a name="input_helper_script_folder"></a> [helper\_script\_folder](#input\_helper\_script\_folder) | Used in scripts | `string` | `"/imagegeneration/helpers"` | no |
| <a name="input_image_folder"></a> [image\_folder](#input\_image\_folder) | Used in scripts | `string` | `"/imagegeneration"` | no |
| <a name="input_image_os"></a> [image\_os](#input\_image\_os) | Used in scripts | `string` | `"ubuntu22"` | no |
| <a name="input_image_version"></a> [image\_version](#input\_image\_version) | Used in scripts | `string` | `"dev"` | no |
| <a name="input_imagedata_file"></a> [imagedata\_file](#input\_imagedata\_file) | Used in scripts | `string` | `"/imagegeneration/imagedata.json"` | no |
| <a name="input_installer_script_folder"></a> [installer\_script\_folder](#input\_installer\_script\_folder) | Used in scripts | `string` | `"/imagegeneration/installers"` | no |
| <a name="input_location"></a> [location](#input\_location) | Used in scripts | `string` | `"West Europe"` | no |
| <a name="input_subscription_id"></a> [subscription\_id](#input\_subscription\_id) | The gallery resource group name, passed as a PKR\_VAR | `string` | `"PKR_VAR_subscription_id"` | no |
| <a name="input_tenant_id"></a> [tenant\_id](#input\_tenant\_id) | The gallery resource group name, passed as a PKR\_VAR | `string` | `"PKR_VAR_tenant_id"` | no |

## Outputs

No outputs.
