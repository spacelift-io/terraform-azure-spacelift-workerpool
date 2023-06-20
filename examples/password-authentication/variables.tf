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
  default = "sp5ft-user-identity"
}

variable "admin_password" {
  type = string
}

variable "env" {
  type    = string
  default = "test"
}

variable "location" {
  type    = string
  default = "westeurope"
}

variable "worker_pool_config" {
  type = string
}

variable "worker_pool_private_key" {
  type = string
}

variable "worker_pool_id" {
  type = string
}
