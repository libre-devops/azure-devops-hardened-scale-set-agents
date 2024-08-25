variable "helper_script_folder" {
  type        = string
  default     = "/imagegeneration/helpers"
  description = "Used in scripts"
}

variable "image_folder" {
  type        = string
  default     = "/imagegeneration"
  description = "Used in scripts"
}

variable "image_os" {
  type        = string
  default     = "ubuntu22"
  description = "Used in scripts"
}

variable "image_version" {
  type        = string
  default     = "uat"
  description = "Used in scripts"
}

variable "imagedata_file" {
  type        = string
  default     = "/imagegeneration/imagedata.json"
  description = "Used in scripts"
}

variable "installer_script_folder" {
  type        = string
  default     = "/imagegeneration/installers"
  description = "Used in scripts"
}

variable "location" {
  type        = string
  default     = "West Europe"
  description = "Used in scripts"
}

// Uses the packer env inbuilt function - https://www.packer.io/docs/templates/hcl_templates/functions/contextual/env
variable "client_id" {
  type        = string
  description = "The client id, passed as a PKR_VAR"
  default     = env("ARM_CLIENT_ID")
}

variable "client_secret" {
  type        = string
  sensitive   = true
  description = "The client_secret, passed as a PKR_VAR"
  default     = env("ARM_CLIENT_SECRET")
}

variable "dockerhub_login" {
  type        = string
  description = "The docker hub login, passed as a PKR_VAR"
  default     = env("PKR_VAR_dockerhub_login")
}

variable "dockerhub_password" {
  type        = string
  description = "The docker hub password passed as a PKR_VAR"
  sensitive   = true
  default     = env("PKR_VAR_dockerhub_password")
}

variable "subscription_id" {
  type        = string
  description = "The gallery resource group name, passed as a PKR_VAR"
  default     = env("ARM_SUBSCRIPTION_ID")
}

variable "tenant_id" {
  type        = string
  description = "The gallery resource group name, passed as a PKR_VAR"
  default     = env("ARM_TENANT_ID")
}

variable "gallery_name" {
  type        = string
  default     = "galldoeuwuat01"
  description = "The wgallery name"
}

variable "gallery_rg_name" {
  type        = string
  default     = "rg-ldo-euw-uat-build"
  description = "The gallery resource group name"
}

variable "virtual_network_name" {
  type        = string
  default     = "vnet-ldo-euw-uat-01"
  description = "The name of the vnet"
}

variable "virtual_network_resource_group_name" {
  type        = string
  default     = "rg-ldo-euw-uat-build"
  description = "The name of the resource group the vnet is in"
}

variable "virtual_network_subnet_name" {
  type        = string
  default     = "sn1-vnet-ldo-euw-uat-01"
  description = "The subnet the VM should be put in"
}

variable "private_virtual_network_with_public_ip" {
  type        = bool
  default     = true
  description = "Determines whether packer should attempt public IP communication"
}

####################################################################################################################

// Begins Packer build Section
source "azure-arm" "build" {

  client_id                 = var.client_id
  client_secret             = var.client_secret
  subscription_id           = var.subscription_id
  tenant_id                 = var.tenant_id
  build_resource_group_name = var.gallery_rg_name
  user_data_file            = "${path.root}/scripts/base/configure-legacy-ssh.sh" # Needed due to bug https://github.com/hashicorp/packer/issues/11656

  // The sku you want to base your image off - In this case - Ubuntu 22
  os_type                 = "Linux"
  image_publisher         = "Canonical"
  image_offer             = "0001-com-ubuntu-server-jammy"
  image_sku               = "22_04-lts"
  vm_size                 = "Standard_B4ms"
  temporary_key_pair_type = "ed25519"

  virtual_network_name                   = var.virtual_network_name
  virtual_network_resource_group_name    = var.virtual_network_resource_group_name
  virtual_network_subnet_name            = var.virtual_network_subnet_name
  private_virtual_network_with_public_ip = var.private_virtual_network_with_public_ip

  // Name of Image which is created by Terraform
  managed_image_name                = "lbdo-azdo-ubuntu-22.04"
  managed_image_resource_group_name = var.gallery_rg_name

  // Shared image gallery is created by terraform in the pre-req step, as is the resource group.
  shared_image_gallery_destination {
    gallery_name   = var.gallery_name
    image_name     = "lbdo-azdo-ubuntu-22.04"
    image_version  = formatdate("YYYY.MM.DD", timestamp())
    resource_group = var.gallery_rg_name
    subscription   = var.subscription_id
    replication_regions = [
      "northeurope"
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
    environment_vars = ["IMAGE_VERSION=${var.image_version}", "IMAGEDATA_FILE=${var.imagedata_file}"]
    execute_command  = "sudo sh -c '{{ .Vars }} {{ .Path }}'"
    scripts          = ["${path.root}/scripts/installers/preimagedata.sh"]
  }

  # Configures OS environment - Needed
  provisioner "shell" {
    environment_vars = ["IMAGE_VERSION=${var.image_version}", "IMAGE_OS=${var.image_os}", "HELPER_SCRIPTS=${var.helper_script_folder}"]
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

  # Installs Docker and Docker-Compose via Moby - Needed
  provisioner "shell" {
    environment_vars = ["HELPER_SCRIPTS=${var.helper_script_folder}", "INSTALLER_SCRIPT_FOLDER=${var.installer_script_folder}", "DOCKERHUB_LOGIN=${var.dockerhub_login}", "DOCKERHUB_PASSWORD=${var.dockerhub_password}"]
    execute_command  = "sudo sh -c '{{ .Vars }} {{ .Path }}'"
    scripts = ["${path.root}/scripts/installers/docker-compose.sh",
    "${path.root}/scripts/installers/docker-moby.sh"]
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
    environment_vars = ["IMAGE_VERSION=${var.image_version}", "INSTALLER_SCRIPT_FOLDER=${var.installer_script_folder}"]
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
