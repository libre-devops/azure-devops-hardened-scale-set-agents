packer {
  required_plugins {
    azure = {
      source  = "github.com/hashicorp/azure"
      version = "~>2.0.4"
    }
  }
}

variable "agent_tools_directory" {
  type        = string
  default     = "C:\\hostedtoolcache\\windows"
  description = "The place where tools will be installed on the image"
}

variable "imagedata_file" {
  type        = string
  default     = "C:\\imagedata.json"
  description = "Where image data is stored"
}

variable "helper_script_folder" {
  type        = string
  default     = "C:\\Program Files\\WindowsPowerShell\\Modules\\"
  description = "Where the helper scripts from the build will be stored"
}

variable "image_folder" {
  type        = string
  default     = "C:\\image"
  description = "The image folder"
}

variable "install_password" {
  type        = string
  sensitive   = true
  description = "The initial installed password used - needed, over"
  default = env("PKR_VAR_install_password")
}

variable "install_user" {
  type        = string
  default     = "installer"
  description = "The initial user used to install stuff - needed"
}

variable "deploy_gui" {
  type        = bool
  default     = false
  description = "Whether to deploy a Windows Server with or without a GUI"
}

locals {
  deploy_gui            = var.deploy_gui
  image_version = formatdate("YYYYMM.DD.HHmmss", timestamp())
  image_os              = "windowsserver2022azure"
  short                 = "lbd"
  env                   = "prd"
  loc                   = "uks"
  location              = "uksouth"
  gallery_name          = "gal${local.short}${local.loc}${local.env}vmss01"
  gallery_rg_name       = "rg-${local.short}-${local.loc}-${local.env}-vmss"
  managed_identity_name = "uid-${local.short}-${local.loc}-${local.env}-vmss-01"
  image_name            = "AzDoWindows2022AzureEdition"
  vnet_rg_name          = local.gallery_rg_name
  vnet_name             = "vnet-${local.short}-${local.loc}-${local.env}-vmss-01"
  subnet_name           = "subnet1"
  use_public_ip         = true
  key_vault_rg_name     = local.gallery_rg_name
  key_vault_name        = "kv-${local.short}-${local.loc}-${local.env}-vmss-01"
}

###### Packer Variables ######

// Uses the packer env inbuilt function - https://www.packer.io/docs/templates/hcl_templates/functions/contextual/env
variable "client_id" {
  type        = string
  description = "The client id, passed as a PKR_VAR"
  default = env("ARM_CLIENT_ID")
}

variable "client_secret" {
  type        = string
  sensitive   = true
  description = "The client_secret, passed as a PKR_VAR"
  default = env("ARM_CLIENT_SECRET")
}

variable "subscription_id" {
  type        = string
  description = "The gallery resource group name, passed as a PKR_VAR"
  default = env("ARM_SUBSCRIPTION_ID")
}

variable "tenant_id" {
  type        = string
  description = "The gallery resource group name, passed as a PKR_VAR"
  default = env("ARM_TENANT_ID")
}

####################################################################################################################

// Begins Packer build Section
source "azure-arm" "build" {

  client_id                 = var.client_id
  client_secret             = var.client_secret
  subscription_id           = var.subscription_id
  tenant_id                 = var.tenant_id
  build_resource_group_name = local.gallery_rg_name
  build_key_vault_name      = local.key_vault_name
  os_type                   = "Windows"
  image_publisher           = "MicrosoftWindowsServer"
  image_offer               = "WindowsServer"
  image_sku                 = local.deploy_gui == true ? "2022-datacenter-azure-edition-hotpatch" : "2022-datacenter-azure-edition-core"
  vm_size                   = "Standard_B2ms"
  communicator              = "winrm"
  winrm_insecure            = "true"
  winrm_use_ssl             = "true"
  winrm_username            = "packer"
  winrm_timeout             = "15m"

  user_assigned_managed_identities = [
    "/subscriptions/${var.subscription_id}/resourcegroups/${local.gallery_rg_name}/providers/Microsoft.ManagedIdentity/userAssignedIdentities/${local.managed_identity_name}"
  ]

  virtual_network_name                = local.vnet_name
  virtual_network_resource_group_name = local.vnet_rg_name
  virtual_network_subnet_name         = local.subnet_name
  private_virtual_network_with_public_ip = local.use_public_ip

  // Name of Image which is created by Terraform
  managed_image_name                = local.image_name
  managed_image_resource_group_name = local.gallery_rg_name

  // Shared image gallery is created by terraform in the pre-req step, as is the resource group.
  shared_image_gallery_destination {
    gallery_name   = local.gallery_name
    image_name     = local.image_name
    image_version  = local.image_version
    resource_group = local.gallery_rg_name
    subscription   = var.subscription_id
    replication_regions = [
      "uksouth"
    ]
  }
}

build {
  sources = ["source.azure-arm.build"]

  provisioner "powershell" {
    inline = [
      "New-Item -Path ${var.image_folder} -ItemType Directory -Force",
      "New-Item -Path ${var.agent_tools_directory} -ItemType Directory -Force"
    ]
  }

  provisioner "file" {
    destination = "${var.helper_script_folder}"
    source      = "${path.root}/scripts/ImageHelpers"
  }

  provisioner "file" {
    destination = "C:/"
    source      = "${path.root}/post-generation"
  }

  provisioner "file" {
    destination = "${var.image_folder}"
    source      = "${path.root}/scripts/Tests"
  }

  provisioner "file" {
    destination = "${var.image_folder}\\toolset.json"
    source      = "${path.root}/toolsets/toolset.json"
  }


  provisioner "file" {
    source      = "scripts/HardeningKitty"
    destination = "C:\\"
  }


  provisioner "powershell" {
    inline = [
      "$password = ConvertTo-SecureString '${var.install_password}' -AsPlainText -Force",
      "New-LocalUser -Name '${var.install_user}' -Password $password -PasswordNeverExpires -UserMayNotChangePassword",
      "if ($?) { Add-LocalGroupMember -Group 'Administrators' -Member '${var.install_user}' } else { Write-Error 'User creation failed.' }",
      "winrm set winrm/config/service/auth '@{Basic=\"true\"}'",
      "winrm get winrm/config/service/auth"
    ]
  }

  provisioner "powershell" {
    inline = ["if (-not ((net localgroup Administrators) -contains '${var.install_user}')) { exit 1 }"]
  }

  provisioner "powershell" {
    elevated_user     = var.install_user
    elevated_password = var.install_password

    environment_vars = [
      "RUN_TASK=false"
    ]
    inline = [
      "if ($env:RUN_TASK -eq 'true') {",
      "  bcdedit.exe /set TESTSIGNING ON",
      "} else {",
      "  Write-Output 'DEPLOY_GUI is not true, skipping...'",
      "}"
    ]
  }

  provisioner "powershell" {
    environment_vars = [
      "IMAGE_VERSION=${local.image_version}",
      "IMAGE_OS=${local.image_os}",
      "AGENT_TOOLSDIRECTORY=${var.agent_tools_directory}",
      "IMAGE_FOLDER=${var.image_folder}",
      "IMAGEDATA_FILE=${var.imagedata_file}",
      "BUILD_WITH_GUI=${local.deploy_gui}"
    ]
    execution_policy = "unrestricted"
    scripts = [
      "${path.root}/scripts/Installers/Configure-Antivirus.ps1",
      "${path.root}/scripts/Installers/Install-PowerShellModules.ps1",
      "${path.root}/scripts/Installers/Install-Choco.ps1",
      "${path.root}/scripts/Installers/Install-CommonUtils.ps1",
      "${path.root}/scripts/Installers/Install-Toolset.ps1",
      "${path.root}/scripts/Installers/Configure-Toolset.ps1",
      "${path.root}/scripts/Installers/Install-PipPackages.ps1",
      "${path.root}/scripts/Installers/Install-HardeningKitty.ps1",
      "${path.root}/scripts/Installers/Initialize-VM.ps1",
      "${path.root}/scripts/Installers/Update-ImageData.ps1",
    ]
  }

  provisioner "powershell" {
    inline = [
      "Write-Output 'Checking if the CSV file exists at the expected path...'",
      "if (Test-Path 'C:\\HardeningKitty\\lists\\finding_list_cis_microsoft_windows_server_2022_22h2_2.0.0_machine.csv') {",
      "  Write-Output 'CSV file found: C:\\HardeningKitty\\lists\\finding_list_cis_microsoft_windows_server_2022_22h2_2.0.0_machine.csv'",
      "} else {",
      "  Write-Error 'CSV file not found: C:\\HardeningKitty\\lists\\finding_list_cis_microsoft_windows_server_2022_22h2_2.0.0_machine.csv'",
      "  exit 1",
      "}"
    ]
  }

  provisioner "powershell" {
    environment_vars = [
      "HARDENING_KITTY_PATH=C:\\HardeningKitty",
      "HARDENING_KITTY_FILES_TO_RUN=finding_list_cis_microsoft_windows_server_2022_22h2_2.0.0_machine.csv;finding_list_cis_microsoft_windows_server_2022_22h2_2.0.0_user.csv;finding_list_msft_security_baseline_windows_server_2022_21h2_member_machine.csv",
      "IMAGE_OS=${local.image_os}",
      "BUILD_WITH_GUI=${local.deploy_gui}"
    ]
    execution_policy = "unrestricted"
    inline = [
      "Write-Output 'Starting HardeningKitty...'",

      # Navigate to the HardeningKitty path
      "cd $env:HARDENING_KITTY_PATH",

      # Split the HARDENING_KITTY_FILES_TO_RUN by ';' and loop through each file
      "$files = $env:HARDENING_KITTY_FILES_TO_RUN -split ';'",
      "foreach ($file in $files) {",
      "Write-Output \"Running HardeningKitty for $file...\"",
      "Invoke-HardeningKitty -Mode HailMary -Log -SkipRestorePoint -Report -FileFindingList \"$env:HARDENING_KITTY_PATH\\lists\\$file\"",
      "}"
    ]
  }


  provisioner "windows-restart" {
    restart_timeout = "10m"
  }

  provisioner "powershell" {
    scripts = [
      "${path.root}/scripts/Installers/Install-RootCA.ps1",
      "${path.root}/scripts/Installers/Disable-JITDebugger.ps1",
    ]
  }

  provisioner "powershell" {
    elevated_password = "${var.install_password}"
    elevated_user     = "${var.install_user}"
    scripts = ["${path.root}/scripts/Installers/Install-WindowsUpdates.ps1"]
  }

  provisioner "windows-restart" {
    check_registry        = true
    restart_check_command = "powershell -command \"& {if ((-not (Get-Process TiWorker.exe -ErrorAction SilentlyContinue)) -and (-not [System.Environment]::HasShutdownStarted) ) { Write-Output 'Restart complete' }}\""
    restart_timeout       = "30m"
  }

  provisioner "powershell" {
    environment_vars = [
      "IMAGE_VERSION=${local.image_version}",
      "IMAGE_OS=${local.image_os}",
      "AGENT_TOOLSDIRECTORY=${var.agent_tools_directory}",
      "IMAGE_FOLDER=${var.image_folder}",
      "IMAGEDATA_FILE=${var.imagedata_file}",
      "BUILD_WITH_GUI=${local.deploy_gui}"
    ]
    pause_before = "2m0s"
    scripts = [
      "${path.root}/scripts/Installers/Wait-WindowsUpdatesForInstall.ps1",
      "${path.root}/scripts/Tests/RunAll-Tests.ps1"
    ]
  }

  provisioner "powershell" {
    environment_vars = [
      "HARDENING_KITTY_PATH=C:\\HardeningKitty",
      "HARDENING_KITTY_FILES_TO_RUN=finding_list_cis_microsoft_windows_server_2022_22h2_2.0.0_machine.csv;finding_list_cis_microsoft_windows_server_2022_22h2_2.0.0_user.csv;finding_list_msft_security_baseline_windows_server_2022_21h2_member_machine.csv",
      "IMAGE_OS=${local.image_os}",
      "BUILD_WITH_GUI=${local.deploy_gui}"
    ]
    execution_policy = "unrestricted"
    inline = [
      "Write-Output 'Starting HardeningKitty...'",

      # Navigate to the HardeningKitty path
      "cd $env:HARDENING_KITTY_PATH",

      # Split the HARDENING_KITTY_FILES_TO_RUN by ';' and loop through each file
      "$files = $env:HARDENING_KITTY_FILES_TO_RUN -split ';'",
      "foreach ($file in $files) {",
      "Write-Output \"Running HardeningKitty for $file...\"",
      "Invoke-HardeningKitty -Mode HailMary -Log -SkipRestorePoint -Report -FileFindingList \"$env:HARDENING_KITTY_PATH\\lists\\$file\"",
      "}"
    ]
  }

  provisioner "powershell" {
    environment_vars = ["INSTALL_USER=${var.install_user}"]
    scripts = [
      "${path.root}/scripts/Installers/Run-NGen.ps1",
      "${path.root}/scripts/Installers/Finalize-VM.ps1"
    ]
    skip_clean = true
  }

  provisioner "powershell" {
    script = "${path.root}/sysprep.ps1"
  }
}
