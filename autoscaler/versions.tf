terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.0"
    }

    external = {
      source = "hashicorp/external"
    }

    http = {
      source = "hashicorp/http"
    }

    null = {
      source = "hashicorp/null"
    }
  }
}
