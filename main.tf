# Read the configuration profile of the person running the script, 
# to use as values for items such as the tenant_id and object_id
data "azurerm_client_config" "current" {}

# Create a resource group
resource "azurerm_resource_group" "resource_group" {
  # =============== Required fields ====================
  location = var.location # Spell it like Azure spells it when you create a resource in the portal (eg. East US)
  name     = var.resource_group_name
}


# Create an Azure Service plan
resource "azurerm_service_plan" "service_plan" {
    # =============== Required fields ====================
  name                = var.service_plan_name
  location            = azurerm_resource_group.resource_group.location
  os_type             = "Windows"
  resource_group_name = azurerm_resource_group.resource_group.name
  sku_name            = "F1"
}

# Create an Azure Windows Web App Service
resource "azurerm_windows_web_app" "web_app" {
  # =============== Required fields ====================
  location                                       = azurerm_resource_group.resource_group.location
  name                                           = var.app_service_name
  resource_group_name                            = azurerm_resource_group.resource_group.name
  service_plan_id                                = azurerm_service_plan.service_plan.id
  site_config {
    always_on  = false
    ftps_state = "FtpsOnly"
    application_stack {
      current_stack  = "dotnet"
      dotnet_version = "v6.0"
    }
  }
  # =============== Optional fields ====================
  https_only                                     = true
  client_affinity_enabled                        = true
  ftp_publish_basic_authentication_enabled       = false # For FTP deployment
  webdeploy_publish_basic_authentication_enabled = true # For other deployment methods that use basic authentication, such as Visual Studio, local Git, and GitHub
}

# Create a User Assigned Managed Identity
resource "azurerm_user_assigned_identity" "managed_identity" {
  # =============== Required fields ====================
  location            = azurerm_resource_group.resource_group.location
  name                = var.managed_identity_name
  resource_group_name = azurerm_resource_group.resource_group.name
}

# Create a Key Vault give Read-Only to the Managed Identity add Certificate
resource "azurerm_key_vault" "key_vault" {
  # =============== Required fields ====================
  name                            = var.key_vault_name
  location                        = azurerm_resource_group.resource_group.location
  resource_group_name             = azurerm_resource_group.resource_group.name
  sku_name                        = "standard"
  tenant_id                       = data.azurerm_client_config.current.tenant_id
  # =============== Optional fields ====================
  enabled_for_deployment          = false
  enabled_for_disk_encryption     = false
  enabled_for_template_deployment = false
  soft_delete_retention_days      = 7
  purge_protection_enabled        = false
}


resource "azurerm_key_vault_access_policy" "access_policy_builder" {
  # =============== Required fields ====================
  key_vault_id = azurerm_key_vault.key_vault.id
  # My ID, admin
  tenant_id = data.azurerm_client_config.current.tenant_id
  object_id = data.azurerm_client_config.current.object_id

  # =============== Optional fields ====================
  # Permissions to keys, secrets, and certificates
  # Add all permissions
  key_permissions = [
    "Backup", "Create", "Decrypt", "Delete", "Encrypt", "Get", "Import", "List", "Purge", "Recover", "Restore", "Sign", "UnwrapKey", "Update", "Verify", "WrapKey", "Release", "Rotate", "GetRotationPolicy", "SetRotationPolicy"
  ]

  secret_permissions = [
    "Backup", "Delete", "Get", "List", "Purge", "Recover", "Restore", "Set"
  ]

  certificate_permissions = [
    "Backup", "Create", "Delete", "DeleteIssuers", "Get", "GetIssuers", "Import", "List", "ListIssuers", "ManageContacts", "ManageIssuers", "Purge", "Recover", "Restore", "SetIssuers", "Update"
  ]
}

resource "azurerm_key_vault_access_policy" "access_policy_agw" {
  # =============== Required fields ====================
  key_vault_id = azurerm_key_vault.key_vault.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_user_assigned_identity.managed_identity.principal_id

  # =============== Optional fields ====================
  secret_permissions = [
    "Get"
  ]
}

# Import a certificate into the Key Vault
resource "azurerm_key_vault_certificate" "certificate" {
  # This was not added until after the access policy was added to the Key Vault, otherwise, 
  # Terraform would add this too early and not be able to confirm the certificate was uploaded 
  # since there was no access policy created yet
  depends_on   = [azurerm_key_vault_access_policy.access_policy_builder, azurerm_key_vault_access_policy.access_policy_agw]
  # =============== Required fields ====================
  name         = var.certificate_name
  key_vault_id = azurerm_key_vault.key_vault.id
  # =============== Optional fields ====================
  certificate {
    contents = filebase64(var.certificate_path)
    password = var.certificate_password
  }
}

# Assign the "Key Vault Reader" role to the managed identity
# Did not use this because I did not want to use the "Key Vault Reader" role, based on what the terraform provider
# documentation said about the TLS termination (the last sentence): For TLS termination with Key Vault certificates
# to work properly existing user-assigned managed identity, which Application Gateway uses to retrieve certificates
#  from Key Vault, should be defined via identity block. Additionally, access policies in the Key Vault to allow 
# the identity to be granted get access to the secret should be defined.
# NOTE: If this is ever used, make sure to edit the depends_on field created above that adds the certificate to 
# the key vault, to include this resource, in case the cert gets uploaded prior to this role assignment, if that 
# happens the terraform script would throw an error because the cert would not be found in the key vault.
# resource "azurerm_role_assignment" "role_assignment" {
#   scope                = azurerm_resource_group.resource_group.name
#   #scope                = azurerm_key_vault.key_vault.id
#   role_definition_name = "Key Vault Reader"
#   principal_id         = azurerm_user_assigned_identity.managed_identity.principal_id
# }

#Create a Virtual Network for the Application Gateway
resource "azurerm_virtual_network" "vnet" {
  # =============== Required fields ====================
  name                = var.virtual_network_name
  resource_group_name = azurerm_resource_group.resource_group.name
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.resource_group.location
}

# Create a subnet for the App Gateway inside the Virtual Network created above
resource "azurerm_subnet" "subnet" {
  # =============== Required fields ====================
  name                 = var.subnet_name
  resource_group_name  = azurerm_resource_group.resource_group.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Create a Public IPv4 Address for the Application Gateway
resource "azurerm_public_ip" "public_ip" {
  # =============== Required fields ====================
  name                = var.public_ip_name
  resource_group_name = azurerm_resource_group.resource_group.name
  location            = azurerm_resource_group.resource_group.location
  allocation_method   = "Static"
  # =============== Optional fields ====================
  ip_version          = "IPv4"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
  sku_tier            = "Regional"
  # RoutingPreference   defaults to "Microsoft network"
  idle_timeout_in_minutes = 4
}

# Create an Application Gateway using the Public IP Address and the Virtual Network and Subnet and the Managed Identity and web app
resource "azurerm_application_gateway" "app_gateway" {
  # =======================================================================
  # REQUIRED FIELDS   REQUIRED FIELDS   REQUIRED FIELDS   REQUIRED FIELDS
  # =======================================================================
  name                = var.app_gateway_name
  resource_group_name = azurerm_resource_group.resource_group.name
  location            = azurerm_resource_group.resource_group.location
  
  backend_address_pool {
    # =============== Required fields ====================
    name = var.app_gateway_backend_address_pool_name
    # =============== Optional fields (can use ip_addresses instead)
    fqdns = [azurerm_windows_web_app.web_app.default_hostname]
  }

  backend_http_settings {
    # =============== Required fields ====================
    cookie_based_affinity = "Disabled"
    name     = var.app_gateway_http_setting_name
    port     = 443
    protocol = "Https"
    # =============== Optional fields ====================
    # Request timeout defaults to 30 seconds
    request_timeout                     = 30
    # The portal UI has a Yes/No for Override with new hostname, but that is not in TF, 
    # so assuming that setting this true means a Yes to Azure that we overriding the host name 
    # from the backend target
    pick_host_name_from_backend_address = true 
    # Use custom probe was Yes/No in the portal UI, but not like that in TF, is disabled by default, enabled by adding name of the probe
    # Backend server's cert is issued by a well-known CA is Yes/No in the portal UI, but not like that in TF, assuming the default is Yes, when you do not add the field that adds "trusted_root_certificate_names"
    # Connection draining was Enable/Disable in the portal UI, but not like that in TF, is disabled by default, enabled by adding connection_draining block
  }
  
  frontend_ip_configuration {
    # =============== Required fields ====================
    name                 = var.app_gateway_frontend_ip_configuration_name
    # =============== Optional fields ====================
    public_ip_address_id = azurerm_public_ip.public_ip.id
  }

  frontend_port {
    # =============== Required fields ====================
    name = var.app_gateway_front_end_port_name
    port = 443
  }

  #Because the subnet below is part of a vnet, TF does not need the vnet name, just the subnet name
  gateway_ip_configuration {
    # =============== Required fields ====================
    name      = var.app_gateway_subnet_name
    subnet_id = azurerm_subnet.subnet.id
  }

  http_listener {
    # =============== Required fields ====================
    name                           = var.app_gateway_listener_name
    frontend_ip_configuration_name = var.app_gateway_frontend_ip_configuration_name
    frontend_port_name             = var.app_gateway_front_end_port_name
    protocol                       = "Https" 
    # =============== Optional fields ====================
    ssl_certificate_name           = azurerm_key_vault_certificate.certificate.name
  }

  request_routing_rule {
    # =============== Required fields ====================
    name                       = var.app_gateway_request_routing_rule_name
    rule_type                  = "Basic"
    http_listener_name         = var.app_gateway_listener_name
    # =============== Optional fields ====================
    backend_address_pool_name  = var.app_gateway_backend_address_pool_name
    backend_http_settings_name = var.app_gateway_http_setting_name
    priority                   = 5
  }

  sku {
    # =============== Required fields ====================
    name     = "Standard_v2"
    tier     = "Standard_v2"
    capacity = 1 # of instances, like "Instance Count" in the portal UI
  }

  # =======================================================================
  # OPTIONAL FIELDS   OPTIONAL FIELDS   OPTIONAL FIELDS   OPTIONAL FIELDS
  # =======================================================================

  # Autoscaling Yes/No in portal UI, but not like that in TF, is disabled by default, enabled by adding autoscale_configuration block

  zones = ["1"]

  # IP address type is a radio button for IPv4 only or Dual Stack (IPv4 & IPv6), but defaults to IPv4 only because of the association we have with the public IP address above which is IPv4 only

  identity {
    # =============== Required fields ====================
    type = "UserAssigned"
    identity_ids = [
      azurerm_user_assigned_identity.managed_identity.id
    ]
  }

  ssl_certificate {
    # =============== Required fields ====================
    name     = azurerm_key_vault_certificate.certificate.name
    # =============== Optional fields ====================
    key_vault_secret_id = azurerm_key_vault_certificate.certificate.secret_id 
  }

}
