locals {
  tags = {
    application = var.application
    env         = var.env
    region      = var.location
  }
}

variable "admin_username" {
  type    = string
  default = "spacelift"
}

variable "application" {
  type    = string
  default = "sp5ft-autoscaler"
}

variable "env" {
  type    = string
  default = "test"
}

variable "location" {
  type    = string
  default = "westeurope"
}


