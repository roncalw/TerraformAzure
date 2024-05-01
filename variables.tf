variable "resource_group_name" {
  description = "The name of the resource group in which to the storage account."
}

variable "location" {
  description = "The Azure region to deploy resources."
}

variable "service_plan_name" {
  description = "Name of the Azure App Service Plan"
}

variable "app_service_name" {
  description = "Name of the Azure App Service"
}

variable "managed_identity_name" {
  description = "Name of the User Assigned Managed Identity"
}

variable "key_vault_name" {
  description = "Name of the Azure Key Vault"
}

variable "certificate_name" {
  description = "Name of the Azure Key Vault Certificate"
}

variable "certificate_path" {
  description = "Path to the Azure Key Vault Certificate"
}

variable "certificate_password" {
  description = "Password to the Azure Key Vault Certificate"
  sensitive   = true
}

variable "virtual_network_name" {
  description = "Name of the Azure Virtual Network"
}

variable "subnet_name" {
  description = "Name of the Azure Virtual Network Subnet"
}

variable "public_ip_name" {
  description = "Name of the Azure Public IP"
}

variable "app_gateway_name" {
  description = "Name of the Azure Application Gateway"
}

variable "app_gateway_subnet_name" {
  description = "Name of the Azure Application Gateway Subnet"
}

variable "app_gateway_front_end_port_name" {
  description = "Name of the Azure Virtual Network Frontend Port"
}

variable "app_gateway_frontend_ip_configuration_name" {
  description = "Name of the Azure Virtual Network Frontend Port"
}

variable "app_gateway_backend_address_pool_name" {
  description = "Name of the Azure Application Gateway Backend Address Pool"
}

variable "app_gateway_http_setting_name" {
  description = "Name of the Azure Application Gateway HTTP Setting"
}

variable "app_gateway_listener_name" {
  description = "Name of the Azure Application Gateway Listener"
}

variable "app_gateway_request_routing_rule_name" {
  description = "Name of the Azure Application Gateway Request Routing Rule"
}