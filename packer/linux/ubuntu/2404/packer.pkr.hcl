# ============================================================================
#  PACKER TEMPLATE – Ubuntu 24.04 Azure Image with CIS Hardening
#  All provisioner blocks now use a consistent, searchable header style.
#  Each header follows the pattern:
#  ########################################################################
#  # <STAGE> – <Short description>
#  ########################################################################
# ============================================================================

packer {
  required_plugins {
    azure = {
      source  = "github.com/hashicorp/azure"
      version = "~>2.0.4"
    }
    ansible = {
      source  = "github.com/hashicorp/ansible"
      version = ">= 1.1.2"
    }
  }
}

# ---------------------------------------------------------------------------
#  VARIABLES
# ---------------------------------------------------------------------------

variable "agent_tools_directory" {
  type        = string
  default     = "/opt/hostedtoolcache/linux"
  description = "Location for tool cache"
}

variable "imagedata_file" {
  type        = string
  default     = "/imagegeneration/imagedata.json"
  description = "Where image‑generation metadata is stored"
}

variable "helper_script_folder" {
  type        = string
  default     = "/imagegeneration/helpers"
  description = "Helper scripts path"
}

variable "image_folder" {
  type        = string
  default     = "/imagegeneration"
  description = "Root folder on the VM that holds build artefacts"
}

variable "installer_script_folder" {
  type        = string
  default     = "/imagegeneration/installers"
  description = "Installer script path"
}

variable "image_os" {
  type        = string
  default     = "ubuntu24"
  description = "OS identifier passed into scripts"
}

variable "install_password" {
  type      = string
  default   = env("PKR_VAR_install_password")
  sensitive = true
}

# ---------------------------------------------------------------------------
#  LOCALS
# ---------------------------------------------------------------------------

locals {
  image_os              = var.image_os
  image_version         = formatdate("YYYYMM.DD.hhmmss", timestamp())
  short                 = "libd"
  env                   = "dev"
  loc                   = "uks"
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

# ---------------------------------------------------------------------------
#  AZURE SERVICE PRINCIPAL VARIABLES
# ---------------------------------------------------------------------------

variable "arm_client_id" {
  type        = string
  description = "Azure AD Client ID"
  default     = "${env("PKR_VAR_ARM_CLIENT_ID")}"
}

variable "arm_client_secret" {
  type        = string
  sensitive   = true
  description = "Azure AD Client secret"
  default     = "${env("PKR_VAR_ARM_CLIENT_SECRET")}"
}

variable "arm_subscription_id" {
  type        = string
  description = "Azure subscription ID"
  default     = "${env("PKR_VAR_ARM_SUBSCRIPTION_ID")}"
}

variable "arm_tenant_id" {
  type        = string
  description = "Azure AD Tenant ID"
  default     = "${env("ARM_TENANT_ID")}"
}

# ---------------------------------------------------------------------------
#  IMAGE SOURCE (Azure Shared‑Image Gallery)
# ---------------------------------------------------------------------------

source "azure-arm" "build" {
  client_id                 = var.arm_client_id
  client_secret             = var.arm_client_secret
  subscription_id           = var.arm_subscription_id
  tenant_id                 = var.arm_tenant_id
  build_resource_group_name = local.rg_name
  build_key_vault_name      = local.key_vault_name
  user_data_file            = "${path.root}/scripts/base/configure-legacy-ssh.sh" # work‑around packer #11656

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

  shared_image_gallery_destination {
    gallery_name        = local.gallery_name
    image_name          = local.image_name
    image_version       = local.image_version
    resource_group      = local.gallery_rg_name
    subscription        = var.arm_subscription_id
    replication_regions = ["uksouth"]
  }
}

# ===========================================================================
#  BUILD SECTION – Every provisioner now has a consistent banner comment
# ===========================================================================

build {
  sources = ["source.azure-arm.build"]

  ########################################################################
  # PREP – Create work folder with open permissions
  ########################################################################
  provisioner "shell" {
    execute_command = "sudo sh -c '{{ .Vars }} {{ .Path }}'"
    inline = [
      "mkdir ${var.image_folder}",
      "chmod 777 ${var.image_folder}"
    ]
  }

  ########################################################################
  # PREP – Mock / lock APT to avoid race conditions (apt-mock.sh)
  ########################################################################
  provisioner "shell" {
    execute_command = "sudo sh -c '{{ .Vars }} {{ .Path }}'"
    script          = "${path.root}/scripts/base/apt-mock.sh"
  }

  ########################################################################
  # PREP – Add external repositories
  ########################################################################
  provisioner "shell" {
    environment_vars = ["DEBIAN_FRONTEND=noninteractive"]
    execute_command  = "sudo sh -c '{{ .Vars }} {{ .Path }}'"
    scripts          = ["${path.root}/scripts/base/repos.sh"]
  }

  ########################################################################
  # PREP – Baseline apt package updates & upgrades
  ########################################################################
  provisioner "shell" {
    environment_vars = ["DEBIAN_FRONTEND=noninteractive"]
    execute_command  = "sudo sh -c '{{ .Vars }} {{ .Path }}'"
    script           = "${path.root}/scripts/base/apt.sh"
  }

  ########################################################################
  # PREP – Configure PAM limits
  ########################################################################
  provisioner "shell" {
    execute_command = "sudo sh -c '{{ .Vars }} {{ .Path }}'"
    script          = "${path.root}/scripts/base/limits.sh"
  }

  ########################################################################
  # COPY – Helper scripts to VM
  ########################################################################
  provisioner "file" {
    destination = "${var.helper_script_folder}"
    source      = "${path.root}/scripts/helpers"
  }

  ########################################################################
  # COPY – Installers directory
  ########################################################################
  provisioner "file" {
    destination = "${var.installer_script_folder}"
    source      = "${path.root}/scripts/installers"
  }

  ########################################################################
  # COPY – Post generation scripts
  ########################################################################
  provisioner "file" {
    destination = "${var.image_folder}"
    source      = "${path.root}/post-generation"
  }

  ########################################################################
  # COPY – Test scripts
  ########################################################################
  provisioner "file" {
    destination = "${var.image_folder}"
    source      = "${path.root}/scripts/tests"
  }

  ########################################################################
  # COPY – Toolset definition JSON
  ########################################################################
  provisioner "file" {
    destination = "${var.installer_script_folder}/toolset.json"
    source      = "${path.root}/toolsets/toolset.json"
  }

  # ########################################################################
  # # CONFIG – Base environment variables inside image
  # ########################################################################
  # provisioner "shell" {
  #   environment_vars = [
  #     "IMAGE_VERSION=${local.image_version}",
  #     "IMAGE_OS=${var.image_os}",
  #     "HELPER_SCRIPTS=${var.helper_script_folder}"
  #   ]
  #   execute_command = "sudo sh -c '{{ .Vars }} {{ .Path }}'"
  #   scripts         = ["${path.root}/scripts/installers/configure-environment.sh"]
  # }
  #
  # ########################################################################
  # # CONFIG – Snap store + PowerShell Core
  # ########################################################################
  # provisioner "shell" {
  #   environment_vars = ["HELPER_SCRIPTS=${var.helper_script_folder}"]
  #   execute_command  = "sudo sh -c '{{ .Vars }} {{ .Path }}'"
  #   scripts = [
  #     "${path.root}/scripts/installers/complete-snap-setup.sh",
  #     "${path.root}/scripts/installers/powershellcore.sh"
  #   ]
  # }
  #
  # ########################################################################
  # # CONFIG – Repeat Snap setup (idempotent safeguard)
  # ########################################################################
  # provisioner "shell" {
  #   environment_vars = ["HELPER_SCRIPTS=${var.helper_script_folder}"]
  #   execute_command  = "sudo sh -c '{{ .Vars }} {{ .Path }}'"
  #   scripts = [
  #     "${path.root}/scripts/installers/complete-snap-setup.sh",
  #     "${path.root}/scripts/installers/powershellcore.sh"
  #   ]
  # }
  #
  # ########################################################################
  # # APT – Ensure latest security updates via Ansible (ensure-update.yaml)
  # ########################################################################
  # provisioner "ansible" {
  #   playbook_file    = "${path.root}/ansible/installers/ensure-update.yaml"
  #   user             = "packer"
  #   extra_arguments  = ["--become", "--become-user=root"]
  #   ansible_env_vars = ["ANSIBLE_HOST_KEY_CHECKING=False"]
  # }
  #
  # ########################################################################
  # # INSTALL – PowerShell modules for build agents
  # ########################################################################
  # provisioner "shell" {
  #   environment_vars = [
  #     "HELPER_SCRIPTS=${var.helper_script_folder}",
  #     "INSTALLER_SCRIPT_FOLDER=${var.installer_script_folder}"
  #   ]
  #   execute_command = "sudo sh -c '{{ .Vars }} pwsh -f {{ .Path }}'"
  #   scripts         = ["${path.root}/scripts/installers/Install-PowerShellModules.ps1"]
  # }
  #
  # ########################################################################
  # # INSTALL – Core developer tools (basic.sh, containers.sh …)
  # ########################################################################
  # provisioner "shell" {
  #   environment_vars = [
  #     "HELPER_SCRIPTS=${var.helper_script_folder}",
  #     "INSTALLER_SCRIPT_FOLDER=${var.installer_script_folder}",
  #     "DEBIAN_FRONTEND=noninteractive"
  #   ]
  #   execute_command = "sudo sh -c '{{ .Vars }} {{ .Path }}'"
  #   scripts = [
  #     "${path.root}/scripts/installers/basic.sh",
  #     "${path.root}/scripts/installers/containers.sh",
  #     "${path.root}/scripts/installers/git.sh",
  #     "${path.root}/scripts/installers/dpkg-config.sh",
  #     "${path.root}/scripts/installers/yq.sh"
  #   ]
  # }
  #
  # ########################################################################
  # # INSTALL – Homebrew on Linux
  # ########################################################################
  # provisioner "shell" {
  #   environment_vars = [
  #     "HELPER_SCRIPTS=${var.helper_script_folder}",
  #     "DEBIAN_FRONTEND=noninteractive",
  #     "INSTALLER_SCRIPT_FOLDER=${var.installer_script_folder}"
  #   ]
  #   execute_command = "/bin/sh -c '{{ .Vars }} {{ .Path }}'"
  #   scripts         = ["${path.root}/scripts/installers/homebrew.sh"]
  # }
  #
  # ########################################################################
  # # CONFIG – Restart snapd service after installations
  # ########################################################################
  # provisioner "shell" {
  #   execute_command = "sudo sh -c '{{ .Vars }} {{ .Path }}'"
  #   script          = "${path.root}/scripts/base/snap.sh"
  # }
  #
  # ########################################################################
  # # REBOOT – Clean VM state before continuing heavy installs
  # ########################################################################
  # provisioner "shell" {
  #   execute_command   = "/bin/sh -c '{{ .Vars }} {{ .Path }}'"
  #   expect_disconnect = true
  #   scripts           = ["${path.root}/scripts/base/reboot.sh"]
  # }
  #
  # ########################################################################
  # # CLEAN – Remove caches & unwanted packages
  # ########################################################################
  # provisioner "shell" {
  #   execute_command     = "sudo sh -c '{{ .Vars }} {{ .Path }}'"
  #   pause_before        = "1m0s"
  #   scripts             = ["${path.root}/scripts/installers/cleanup.sh"]
  #   start_retry_timeout = "10m"
  # }
  #
  # ########################################################################
  # # CLEAN – Remove APT mock once real installations are complete
  # ########################################################################
  # provisioner "shell" {
  #   execute_command = "sudo sh -c '{{ .Vars }} {{ .Path }}'"
  #   script          = "${path.root}/scripts/base/apt-mock-remove.sh"
  # }
  #
  # ########################################################################
  # # TEST – Run Pester tests against the configured image
  # ########################################################################
  # provisioner "shell" {
  #   environment_vars = [
  #     "IMAGE_VERSION=${local.image_version}",
  #     "INSTALLER_SCRIPT_FOLDER=${var.installer_script_folder}"
  #   ]
  #   inline = [
  #     "pwsh -File ${var.image_folder}/tests/RunAll-Tests.ps1 -OutputDirectory ${var.image_folder}"
  #   ]
  # }

  ########################################################################
  # SECURITY – Set local passwords required by CIS rules 5.2.4 & 5.4.2.4
  ########################################################################
  provisioner "shell" {
    environment_vars = ["INSTALL_PASSWORD=${var.install_password}"]
    inline = [
      "sudo usermod --password \"$(openssl passwd -6 \"$INSTALL_PASSWORD\")\" packer"
    ]
  }

  provisioner "shell" {
    environment_vars = ["ROOT_PASSWORD=${var.install_password}"]
    inline = [
      "sudo usermod --password \"$(openssl passwd -6 \"$ROOT_PASSWORD\")\" root"
    ]
  }

  ########################################################################
  # SECURITY – Run CIS hardening role (Ansible)
  ########################################################################
  provisioner "ansible" {
    playbook_file   = "${path.root}/ansible/cis-hardening/site.yml"
    user            = "packer"
    extra_arguments = ["--become", "--become-user=root"]
    ansible_env_vars = [
      "ANSIBLE_HOST_KEY_CHECKING=False",
      "ANSIBLE_BECOME_PASS=${var.install_password}"
    ]
  }

  #######################################################################
  # REBOOT – Required after CIS removed NOPASSWD
  #######################################################################
  provisioner "shell" {
    environment_vars  = ["SUDO_PASS=${var.install_password}"]

    # --  no {{ .Vars }}  --
    execute_command   = "echo \"$SUDO_PASS\" | sudo -S -p \"\" /bin/sh '{{ .Path }}'"

    expect_disconnect = true
    scripts           = ["${path.root}/scripts/base/reboot.sh"]
  }

  #######################################################################
  # POST‑DEPLOYMENT – Final configuration under strict sudo rules
  #######################################################################
  provisioner "shell" {
    environment_vars = [
      "SUDO_PASS=${var.install_password}",
      "HELPER_SCRIPT_FOLDER=${var.helper_script_folder}",
      "INSTALLER_SCRIPT_FOLDER=${var.installer_script_folder}",
      "IMAGE_FOLDER=${var.image_folder}"
    ]

    execute_command = "echo \"$SUDO_PASS\" | sudo -S -p \"\" /bin/bash '{{ .Path }}'"
    scripts         = ["${path.root}/scripts/installers/post-deployment.sh"]
  }

  #######################################################################
  # SYSPREP – Deprovision VM for Azure SIG publishing
  #######################################################################
  provisioner "shell" {
    environment_vars = ["SUDO_PASS=${var.install_password}"]

    inline = [
      "echo \"$SUDO_PASS\" | sudo -S -p \"\" /usr/sbin/waagent -force -deprovision+user && export HISTSIZE=0 && sync"
    ]
  }

}
