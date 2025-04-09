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
  default     = "/opt/hostedtoolcache/linux"
  description = "The place where tools will be installed on the image"
}

variable "imagedata_file" {
  type        = string
  default     = "/imagegeneration/imagedata.json"
  description = "Where image data is stored"
}

variable "helper_script_folder" {
  type        = string
  default     = "/imagegeneration/helpers"
  description = "Where the helper scripts from the build will be stored"
}

variable "image_folder" {
  type        = string
  default     = "/imagegeneration"
  description = "The image folder"
}

variable "installer_script_folder" {
  type        = string
  default     = "/imagegeneration/installers"
  description = "Where the install scripts live"
}

variable "image_os" {
  type        = string
  default     = "ubuntu24"
  description = "Used in scripts"
}

locals {
  image_os              = var.image_os
  image_version         = formatdate("YYYYMM.DD.hhmmss", timestamp())
  short                 = "libd"
  env                   = "dev"
  loc                   = "dev"
  location              = "uksouth"
  rg_name               = "rg-${local.short}-${local.loc}-${local.env}-01"
  gallery_name          = "gal${local.short}${local.loc}${local.env}01"
  gallery_rg_name       = local.rg_name
  managed_identity_name = "uid-${local.short}-${local.loc}-${local.env}-01"
  image_name            = "AzDoUbuntu2404"
  vnet_rg_name          = local.rg_name
  vnet_name             = "vnet-${local.short}-${local.loc}-${local.env}-01"
  subnet_name           = "VMSubnet"
  use_public_ip         = true
  key_vault_rg_name     = local.rg_name
  key_vault_name        = "kv-${local.short}-${local.loc}-${local.env}-01"
}

###### Packer Variables ######

variable "arm_client_id" {
  type        = string
  description = "The client id, passed as a PKR_VAR"
  default     = "${env("PKR_VAR_ARM_CLIENT_ID")}"
}

variable "arm_client_secret" {
  type        = string
  sensitive   = true
  description = "The client secret, passed as a PKR_VAR"
  default     = "${env("PKR_VAR_ARM_CLIENT_SECRET")}"
}

variable "arm_subscription_id" {
  type        = string
  description = "The subscription id, passed as a PKR_VAR"
  default     = "${env("PKR_VAR_ARM_SUBSCRIPTION_ID")}"
}

variable "arm_tenant_id" {
  type        = string
  description = "The tenant id, passed as a PKR_VAR"
  default     = "${env("ARM_TENANT_ID")}"
}


####################################################################################################################

// Begins Packer build Section
source "azure-arm" "build" {

  client_id                 = var.arm_client_id
  client_secret             = var.arm_client_secret
  subscription_id           = var.arm_subscription_id
  tenant_id                 = var.arm_tenant_id
  build_resource_group_name = local.rg_name
  build_key_vault_name      = local.key_vault_name
  user_data_file            = "${path.root}/scripts/base/configure-legacy-ssh.sh" # Needed due to bug https://github.com/hashicorp/packer/issues/11656

  // The sku you want to base your image off - In this case - Ubuntu 24.04
  os_type                 = "Linux"
  image_publisher         = "Canonical"
  image_offer             = "ubuntu-24_04-lts"
  vm_size                 = "Standard_D4ds_v5"
  image_sku               = "server"
  temporary_key_pair_type = "ed25519"

  virtual_network_name                   = local.vnet_name
  virtual_network_resource_group_name    = local.vnet_rg_name
  virtual_network_subnet_name            = local.subnet_name
  private_virtual_network_with_public_ip = local.use_public_ip


  // Shared image gallery is created by terraform in the pre-req step, as is the resource group.
  shared_image_gallery_destination {
    gallery_name   = local.gallery_name
    image_name     = local.image_name
    image_version  = local.image_version
    resource_group = local.gallery_rg_name
    subscription   = var.arm_subscription_id
    replication_regions = [
      "uksouth"
    ]
  }
}

build {
  sources = ["source.azure-arm.build"]

  # Creates a folder for the prep of the image - Needed
  provisioner "shell" {
    execute_command = "sudo sh -c '{{ .Vars }} {{ .Path }}'"
    inline          = ["mkdir ${var.image_folder}", "chmod 777 ${var.image_folder}"]
  }

  # Fixes an error in the Linux machine which causes the WALinuxAgent to break - https://github.com/Azure/azure-linux-extensions/issues/1238 - Needed
  provisioner "shell" {
    execute_command = "sudo sh -c '{{ .Vars }} {{ .Path }}'"
    script          = "${path.root}/scripts/base/apt-mock.sh"
  }

  # Adds various repos to the image, such as the Microsoft one - Needed
  provisioner "shell" {
    environment_vars = ["DEBIAN_FRONTEND=noninteractive"]
    execute_command  = "sudo sh -c '{{ .Vars }} {{ .Path }}'"
    scripts          = ["${path.root}/scripts/base/repos.sh"]
  }

  # Preps a bunch of apt services - Needed
  provisioner "shell" {
    environment_vars = ["DEBIAN_FRONTEND=noninteractive"]
    execute_command  = "sudo sh -c '{{ .Vars }} {{ .Path }}'"
    script           = "${path.root}/scripts/base/apt.sh"
  }

  # Sets Pam limits - Potentially Unneeded
  provisioner "shell" {
    execute_command = "sudo sh -c '{{ .Vars }} {{ .Path }}'"
    script          = "${path.root}/scripts/base/limits.sh"
  }

  # Creates folder - Needed
  provisioner "file" {
    destination = "${var.helper_script_folder}"
    source      = "${path.root}/scripts/helpers"
  }

  # Creates folder - Needed
  provisioner "file" {
    destination = "${var.installer_script_folder}"
    source      = "${path.root}/scripts/installers"
  }

  # Creates folder - Needed
  provisioner "file" {
    destination = "${var.image_folder}"
    source      = "${path.root}/post-generation"
  }

  # Creates folder - Needed
  provisioner "file" {
    destination = "${var.image_folder}"
    source      = "${path.root}/scripts/tests"
  }

  # Creates folder - Needed
  provisioner "file" {
    destination = "${var.image_folder}"
    source      = "${path.root}/scripts/SoftwareReport"
  }

  # Loads JSON file with toolset within - Needed
  provisioner "file" {
    destination = "${var.installer_script_folder}/toolset.json"
    source      = "${path.root}/toolsets/toolset-2204.json"
  }

  # Primes image data file - Probably Unneeded, leaving
  provisioner "shell" {
    environment_vars = ["IMAGE_VERSION=${local.image_version}", "IMAGEDATA_FILE=${var.imagedata_file}"]
    execute_command  = "sudo sh -c '{{ .Vars }} {{ .Path }}'"
    scripts          = ["${path.root}/scripts/installers/preimagedata.sh"]
  }

  # Configures OS environment - Needed
  provisioner "shell" {
    environment_vars = ["IMAGE_VERSION=${local.image_version}", "IMAGE_OS=${var.image_os}", "HELPER_SCRIPTS=${var.helper_script_folder}"]
    execute_command  = "sudo sh -c '{{ .Vars }} {{ .Path }}'"
    scripts          = ["${path.root}/scripts/installers/configure-environment.sh"]
  }

  # Configures Snapstore (ew) - Needed
  provisioner "shell" {
    environment_vars = ["HELPER_SCRIPTS=${var.helper_script_folder}"]
    execute_command  = "sudo sh -c '{{ .Vars }} {{ .Path }}'"
    scripts = [
      "${path.root}/scripts/installers/complete-snap-setup.sh",
    "${path.root}/scripts/installers/powershellcore.sh"]
  }

  # Install PowerShell Modules - Needed
  provisioner "shell" {
    environment_vars = ["HELPER_SCRIPTS=${var.helper_script_folder}", "INSTALLER_SCRIPT_FOLDER=${var.installer_script_folder}"]
    execute_command  = "sudo sh -c '{{ .Vars }} pwsh -f {{ .Path }}'"
    scripts = ["${path.root}/scripts/installers/Install-PowerShellModules.ps1",
    "${path.root}/scripts/installers/Install-AzureModules.ps1"]
  }

  # Installs packages added in the installers dir - Needed
  provisioner "shell" {
    environment_vars = ["HELPER_SCRIPTS=${var.helper_script_folder}", "INSTALLER_SCRIPT_FOLDER=${var.installer_script_folder}", "DEBIAN_FRONTEND=noninteractive"]
    execute_command  = "sudo sh -c '{{ .Vars }} {{ .Path }}'"
    scripts = [
      "${path.root}/scripts/installers/azcopy.sh",
      "${path.root}/scripts/installers/azure-cli.sh",
      "${path.root}/scripts/installers/azure-devops-cli.sh",
      "${path.root}/scripts/installers/basic.sh",
      "${path.root}/scripts/installers/containers.sh",
      "${path.root}/scripts/installers/dotnetcore-sdk.sh",
      "${path.root}/scripts/installers/git.sh",
      "${path.root}/scripts/installers/github-cli.sh",
      "${path.root}/scripts/installers/kubernetes-tools.sh",
      "${path.root}/scripts/installers/packer.sh",
      "${path.root}/scripts/installers/vcpkg.sh",
      "${path.root}/scripts/installers/dpkg-config.sh",
      "${path.root}/scripts/installers/yq.sh",
      "${path.root}/scripts/installers/pypy.sh",
      "${path.root}/scripts/installers/python.sh",
    ]
  }

  # Installs everything in toolset.json as part of the toolcache section (which is basically everything) - Needed
  provisioner "shell" {
    environment_vars = ["HELPER_SCRIPTS=${var.helper_script_folder}", "INSTALLER_SCRIPT_FOLDER=${var.installer_script_folder}"]
    execute_command  = "sudo sh -c '{{ .Vars }} pwsh -f {{ .Path }}'"
    scripts = ["${path.root}/scripts/installers/Install-Toolset.ps1",
    "${path.root}/scripts/installers/Configure-Toolset.ps1"]
  }

  # Installs everything in the PipX section - Needed
  provisioner "shell" {
    environment_vars = ["HELPER_SCRIPTS=${var.helper_script_folder}", "INSTALLER_SCRIPT_FOLDER=${var.installer_script_folder}"]
    execute_command  = "sudo sh -c '{{ .Vars }} {{ .Path }}'"
    scripts          = ["${path.root}/scripts/installers/pipx-packages.sh"]
  }

  # Restarts the snapd - Needed
  provisioner "shell" {
    environment_vars = ["HELPER_SCRIPTS=${var.helper_script_folder}", "DEBIAN_FRONTEND=noninteractive", "INSTALLER_SCRIPT_FOLDER=${var.installer_script_folder}"]
    execute_command  = "/bin/sh -c '{{ .Vars }} {{ .Path }}'"
    scripts          = ["${path.root}/scripts/installers/homebrew.sh"]
  }

  # Restarts the snapd - Needed
  provisioner "shell" {
    execute_command = "sudo sh -c '{{ .Vars }} {{ .Path }}'"
    script          = "${path.root}/scripts/base/snap.sh"
  }

  # Reboots the VM - Needed
  provisioner "shell" {
    execute_command   = "/bin/sh -c '{{ .Vars }} {{ .Path }}'"
    expect_disconnect = true
    scripts           = ["${path.root}/scripts/base/reboot.sh"]
  }

  # Cleans up junk - Needed
  provisioner "shell" {
    execute_command     = "sudo sh -c '{{ .Vars }} {{ .Path }}'"
    pause_before        = "1m0s"
    scripts             = ["${path.root}/scripts/installers/cleanup.sh"]
    start_retry_timeout = "10m"
  }

  # Removes apt mock - Needed
  provisioner "shell" {
    execute_command = "sudo sh -c '{{ .Vars }} {{ .Path }}'"
    script          = "${path.root}/scripts/base/apt-mock-remove.sh"
  }

  # Runs Pester tests - Needed
  provisioner "shell" {
    environment_vars = ["IMAGE_VERSION=${local.image_version}", "INSTALLER_SCRIPT_FOLDER=${var.installer_script_folder}"]
    inline           = ["pwsh -File ${var.image_folder}/tests/RunAll-Tests.ps1 -OutputDirectory ${var.image_folder}"]
  }

  # Post-deployment - Needed
  provisioner "shell" {
    environment_vars = ["HELPER_SCRIPT_FOLDER=${var.helper_script_folder}", "INSTALLER_SCRIPT_FOLDER=${var.installer_script_folder}", "IMAGE_FOLDER=${var.image_folder}"]
    execute_command  = "sudo sh -c '{{ .Vars }} {{ .Path }}'"
    scripts          = ["${path.root}/scripts/installers/post-deployment.sh"]
  }

  # Adds Linux VM Agent for Azure - not Needed but extremely useful, so leaving.
  provisioner "shell" {
    execute_command = "sudo sh -c '{{ .Vars }} {{ .Path }}'"
    inline          = ["sleep 30", "/usr/sbin/waagent -force -deprovision+user && export HISTSIZE=0 && sync"]
  }
}
