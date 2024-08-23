terraform {
  #Use the latest by default, uncomment below to pin or use hcl.lck
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    }

    azuredevops = {
      source = "microsoft/azuredevops"
    }

    random = {
      source = "hashicorp/random"
    }
  }
  backend "azurerm" {
  }
}
