provider "azurerm" {
features {}
}


#variables
variable "A-location" {
    description = "Location of the resources"
    #default     = "eastus"
}

variable "B-resource_group_name" {
    description = "Name of the resource group to create"
}

variable "C-home_public_ip" {
    description = "Your home public ip address"
}

variable "D-username" {
    description = "Username for Virtual Machines"
    #default     = "azureuser"
}

variable "E-password" {
    description = "Password for Virtual Machines"
    sensitive = true
}

resource "azurerm_resource_group" "RG" {
  location = var.A-location
  name     = var.B-resource_group_name
}

#logic app to self destruct resourcegroup after 24hrs
data "azurerm_subscription" "sub" {
}

resource "azurerm_logic_app_workflow" "workflow1" {
  location = azurerm_resource_group.RG.location
  name     = "labdelete"
  resource_group_name = azurerm_resource_group.RG.name
  identity {
    type = "SystemAssigned"
  }
  depends_on = [
    azurerm_resource_group.RG,
  ]
}
resource "azurerm_role_assignment" "contrib1" {
  scope = azurerm_resource_group.RG.id
  role_definition_name = "Contributor"
  principal_id  = azurerm_logic_app_workflow.workflow1.identity[0].principal_id
  depends_on = [azurerm_logic_app_workflow.workflow1]
}


resource "azurerm_resource_group_template_deployment" "apiconnections" {
  name                = "group-deploy"
  resource_group_name = azurerm_resource_group.RG.name
  deployment_mode     = "Incremental"
  template_content = <<TEMPLATE
{
    "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {},
    "variables": {},
    "resources": [
        {
            "type": "Microsoft.Web/connections",
            "apiVersion": "2016-06-01",
            "name": "arm-1",
            "location": "${azurerm_resource_group.RG.location}",
            "kind": "V1",
            "properties": {
                "displayName": "labdeleteconn1",
                "authenticatedUser": {},
                "statuses": [
                    {
                        "status": "Ready"
                    }
                ],
                "connectionState": "Enabled",
                "customParameterValues": {},
                "alternativeParameterValues": {},
                "parameterValueType": "Alternative",
                "createdTime": "2023-05-21T23:07:20.1346918Z",
                "changedTime": "2023-05-21T23:07:20.1346918Z",
                "api": {
                    "name": "arm",
                    "displayName": "Azure Resource Manager",
                    "description": "Azure Resource Manager exposes the APIs to manage all of your Azure resources.",
                    "iconUri": "https://connectoricons-prod.azureedge.net/laborbol/fixes/path-traversal/1.0.1552.2695/arm/icon.png",
                    "brandColor": "#003056",
                    "id": "/subscriptions/${data.azurerm_subscription.sub.subscription_id}/providers/Microsoft.Web/locations/${azurerm_resource_group.RG.location}/managedApis/arm",
                    "type": "Microsoft.Web/locations/managedApis"
                },
                "testLinks": []
            }
        },
        {
            "type": "Microsoft.Logic/workflows",
            "apiVersion": "2017-07-01",
            "name": "labdelete",
            "location": "${azurerm_resource_group.RG.location}",
            "dependsOn": [
                "[resourceId('Microsoft.Web/connections', 'arm-1')]"
            ],
            "identity": {
                "type": "SystemAssigned"
            },
            "properties": {
                "state": "Enabled",
                "definition": {
                    "$schema": "https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#",
                    "contentVersion": "1.0.0.0",
                    "parameters": {
                        "$connections": {
                            "defaultValue": {},
                            "type": "Object"
                        }
                    },
                    "triggers": {
                        "Recurrence": {
                            "recurrence": {
                                "frequency": "Minute",
                                "interval": 3,
                                "startTime": "${timeadd(timestamp(),"24h")}"
                            },
                            "evaluatedRecurrence": {
                                "frequency": "Minute",
                                "interval": 3,
                                "startTime": "${timeadd(timestamp(),"24h")}"
                            },
                            "type": "Recurrence"
                        }
                    },
                    "actions": {
                        "Delete_a_resource_group": {
                            "runAfter": {},
                            "type": "ApiConnection",
                            "inputs": {
                                "host": {
                                    "connection": {
                                        "name": "@parameters('$connections')['arm']['connectionId']"
                                    }
                                },
                                "method": "delete",
                                "path": "/subscriptions/@{encodeURIComponent('${data.azurerm_subscription.sub.subscription_id}')}/resourcegroups/@{encodeURIComponent('${azurerm_resource_group.RG.name}')}",
                                "queries": {
                                    "x-ms-api-version": "2016-06-01"
                                }
                            }
                        }
                    },
                    "outputs": {}
                },
                "parameters": {
                    "$connections": {
                        "value": {
                            "arm": {
                                "connectionId": "[resourceId('Microsoft.Web/connections', 'arm-1')]",
                                "connectionName": "arm-1",
                                "connectionProperties": {
                                    "authentication": {
                                        "type": "ManagedServiceIdentity"
                                    }
                                },
                                "id": "/subscriptions/${data.azurerm_subscription.sub.subscription_id}/providers/Microsoft.Web/locations/${azurerm_resource_group.RG.location}/managedApis/arm"
                            }
                        }
                    }
                }
            }
        }
    ]
}
TEMPLATE
}


resource "azurerm_resource_group_template_deployment" "secret" {
  name                = "secret-deploy"
  resource_group_name = azurerm_resource_group.RG.name
  deployment_mode     = "Incremental"
  template_content = <<TEMPLATE
{
    "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {},
    "variables": {},
    "resources": [
      {
      "type": "Microsoft.Resources/deploymentScripts",
      "apiVersion": "2020-10-01",
      "name": "createcerts",
      "location": "${azurerm_key_vault.certkv.location}",
      "kind": "AzurePowerShell",
      "properties": {
        "forceUpdateTag": "2",
        "azPowerShellVersion": "3.0",
        "scriptContent": "# Write the config to file\n$opensslConfig=@'\n[ req ]\ndefault_bits        = 4096\ndistinguished_name  = req_distinguished_name\nstring_mask         = utf8only\ndefault_md          = sha512\n\n[ req_distinguished_name ]\ncountryName                     = Country Name (2 letter code)\nstateOrProvinceName             = State or Province Name\nlocalityName                    = Locality Name\n0.organizationName              = Organization Name\norganizationalUnitName          = Organizational Unit Name\ncommonName                      = testcert.com\nemailAddress                    = Email Address\n\n[ rootCA_ext ]\nsubjectKeyIdentifier = hash\nauthorityKeyIdentifier = keyid:always,issuer\nbasicConstraints = critical, CA:true\nkeyUsage = critical, digitalSignature, cRLSign, keyCertSign\n\n[ interCA_ext ]\nsubjectKeyIdentifier = hash\nauthorityKeyIdentifier = keyid:always,issuer\nbasicConstraints = critical, CA:true, pathlen:1\nkeyUsage = critical, digitalSignature, cRLSign, keyCertSign\n\n[ server_ext ]\nsubjectKeyIdentifier = hash\nauthorityKeyIdentifier = keyid:always,issuer\nbasicConstraints = critical, CA:false\nkeyUsage = critical, digitalSignature\nextendedKeyUsage = serverAuth\n'@\n\nSet-Content -Path openssl.cnf -Value $opensslConfig\n\n# Create root CA\nopenssl req -x509 -new -nodes -newkey rsa:4096 -keyout rootCA.key -sha256 -days 3650 -out rootCA.crt -subj '/C=US/ST=US/O=Self Signed/CN=testcert.com' -addext 'subjectAltName=DNS:testcert.com' -config openssl.cnf -extensions rootCA_ext\n\n#Export the root CA into PFX\nopenssl pkcs12 -export -out rootCA.pfx -inkey rootCA.key -in rootCA.crt -password 'pass:'\n\n#Convert the PFX and public key into base64\n$rootCa2 = [Convert]::ToBase64String((Get-Content -Path rootCA.crt -AsByteStream -Raw))\n$rootCa = [Convert]::ToBase64String((Get-Content -Path rootCA.pfx -AsByteStream -Raw))\n\n# Assign outputs\n$DeploymentScriptOutputs = @{}\n$DeploymentScriptOutputs['rootca2'] = $rootCa2\n$DeploymentScriptOutputs['rootca'] = $rootCa\n",
        "timeout": "PT5M",
        "cleanupPreference": "OnSuccess",
        "retentionInterval": "P1D"
      }
    },
    
    {
      "type": "Microsoft.KeyVault/vaults/secrets",
      "apiVersion": "2019-09-01",
      "name": "${azurerm_key_vault.certkv.name}/secret1",
      "location": "${azurerm_key_vault.certkv.location}",
      "properties": {
        "value": "[reference(resourceId('Microsoft.Resources/deploymentScripts', 'createcerts'), '2020-10-01').outputs.rootca]"
      },
      "dependsOn": [
        "[resourceId('Microsoft.Resources/deploymentScripts', 'createcerts')]"
        
      ]
    }
    ]
}
TEMPLATE
depends_on = [ azurerm_key_vault.certkv ]
}


#identity, keyvault, and certs
resource "azurerm_user_assigned_identity" "appgwidentity" {
  location = azurerm_resource_group.RG.location
  resource_group_name = azurerm_resource_group.RG.name
  name = "appgwidentity"
}

data "azurerm_client_config" "current" {

}
resource "random_pet" "name" {
  length = 2
}

resource "azurerm_key_vault" "certkv" {
  name                        = "certKV-${random_pet.name.id}"
  location                    = azurerm_user_assigned_identity.appgwidentity.location
  resource_group_name         = azurerm_resource_group.RG.name
  #enabled_for_disk_encryption = true
  enabled_for_deployment = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  #soft_delete_retention_days  = 7
  #purge_protection_enabled    = false

  sku_name = "standard"

  access_policy {
    tenant_id = azurerm_user_assigned_identity.appgwidentity.tenant_id
    object_id = azurerm_user_assigned_identity.appgwidentity.principal_id

    secret_permissions = [
      "Get",
      "List",
      "Set"
    ]

  }
  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    secret_permissions = [
      "Get",
      "List",
      "Set"
    ]

  }
}

#vnets and subnets
resource "azurerm_virtual_network" "hub-vnet" {
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.RG.location
  name                = "AZ-hub-vnet"
  resource_group_name = azurerm_resource_group.RG.name
  subnet {
    address_prefix     = "10.0.0.0/24"
    name                 = "default"
    security_group = azurerm_network_security_group.hubvnetNSG.id
  }
  subnet {
    address_prefix     = "10.0.1.0/24"
    name                 = "GatewaySubnet" 
  }
  subnet {
    address_prefix     = "10.0.2.0/24"
    name                 = "AppGatewaySubnet" 
  }
  timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
  }
  
}


resource "azurerm_virtual_network" "spoke-vnet" {
  address_space       = ["10.250.0.0/16"]
  location            = azurerm_resource_group.RG.location
  name                = "AZ-spoke-vnet"
  resource_group_name = azurerm_resource_group.RG.name
  subnet {
    address_prefix     = "10.250.0.0/24"
    name                 = "default"
    security_group = azurerm_network_security_group.spokevnetNSG.id
  }
  subnet {
    address_prefix     = "10.250.1.0/24"
    name                 = "GatewaySubnet" 
  }
  timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
  }
  
}

#NSG's
resource "azurerm_network_security_group" "hubvnetNSG" {
  location            = azurerm_resource_group.RG.location
  name                = "AZ-hub-vnet-default-nsg"
  resource_group_name = azurerm_resource_group.RG.name
  timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
  }
  
}


resource "azurerm_network_security_group" "spokevnetNSG" {
  location            = azurerm_resource_group.RG.location
  name                = "AZ-spoke-vnet-default-nsg"
  resource_group_name = azurerm_resource_group.RG.name
  timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
  }
  
}
resource "azurerm_network_security_rule" "spokevnetnsgrule1" {
  access                      = "Allow"
  destination_address_prefix  = "*"
  destination_port_range      = "3389"
  direction                   = "Inbound"
  name                        = "AllowCidrBlockRDPInbound"
  network_security_group_name = "AZ-spoke-vnet-default-nsg"
  priority                    = 2711
  protocol                    = "Tcp"
  resource_group_name         = azurerm_network_security_group.spokevnetNSG.resource_group_name
  source_address_prefix       = var.C-home_public_ip
  source_port_range           = "*"
  timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
  }
  
}





#Public IP's
resource "azurerm_public_ip" "appgw-pip" {
  name                = "appgwgw-pip"
  location            = azurerm_resource_group.RG.location
  resource_group_name = azurerm_resource_group.RG.name
  allocation_method = "Static"
  sku = "Standard"
  timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
  }
  
}

resource "azurerm_public_ip" "spokevm-pip" {
  name                = "spokevm-pip"
  location            = azurerm_resource_group.RG.location
  resource_group_name = azurerm_resource_group.RG.name
  allocation_method = "Dynamic"
  timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
  }
  
}
data "azurerm_key_vault_secret" "secret1" {
  key_vault_id = azurerm_key_vault.certkv.id
  name = "secret1"
  depends_on = [ azurerm_resource_group_template_deployment.secret ]
}

#appgw
# since these variables are re-used - a locals block makes this more maintainable
locals {
  backend_address_pool_name      = "bepool"
  frontend_port_name             = "fe-port"
  frontend_ip_configuration_name = "fe-ip"
  http_setting_name              = "httpsetting"
  listener_name                  = "listener1"
  request_routing_rule_name      = "rule1"
  redirect_configuration_name    = "redir"
}

resource "azurerm_application_gateway" "appgw1" {
  name                = "appgateway"
  resource_group_name = azurerm_resource_group.RG.name
  location            = azurerm_resource_group.RG.location

  sku {
    name     = "Standard_v2"
    tier     = "Standard_v2"
    capacity = 2
  }

  gateway_ip_configuration {
    name      = "app-gateway-ip-configuration"
    subnet_id = azurerm_virtual_network.hub-vnet.subnet.*.id[2]
  }

  frontend_port {
    name = local.frontend_port_name
    port = 443
  }

  frontend_ip_configuration {
    name                 = local.frontend_ip_configuration_name
    public_ip_address_id = azurerm_public_ip.appgw-pip.id
  }

  backend_address_pool {
    name = local.backend_address_pool_name

  }

  backend_http_settings {
    name                  = local.http_setting_name
    cookie_based_affinity = "Disabled"
    path                  = "/"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 60
  }

  http_listener {
    name                           = local.listener_name
    frontend_ip_configuration_name = local.frontend_ip_configuration_name
    frontend_port_name             = local.frontend_port_name
    protocol                       = "Https"
    ssl_certificate_name = data.azurerm_key_vault_secret.secret1.name    
  }

  request_routing_rule {
    name                       = local.request_routing_rule_name
    priority                   = 9
    rule_type                  = "Basic"
    http_listener_name         = local.listener_name
    backend_address_pool_name  = local.backend_address_pool_name
    backend_http_settings_name = local.http_setting_name
  }
  identity {
   type = "UserAssigned"
   identity_ids = [azurerm_user_assigned_identity.appgwidentity.id] 
  }
  ssl_certificate {    
    key_vault_secret_id = data.azurerm_key_vault_secret.secret1.id
    name = data.azurerm_key_vault_secret.secret1.name
  }
  depends_on = [ data.azurerm_key_vault_secret.secret1,azurerm_user_assigned_identity.appgwidentity ]
}

resource "azurerm_network_interface" "vnic" {
  count               = 2
  name                = "vnic-${count.index}"
  location            = azurerm_resource_group.RG.location
  resource_group_name = azurerm_resource_group.RG.name

  ip_configuration {
    name                          = "ipconfig${count.index}"
    subnet_id                     = azurerm_virtual_network.hub-vnet.subnet.*.id[0]
    private_ip_address_allocation = "Dynamic"
    primary                       = true
    #public_ip_address_id = azurerm_public_ip.PIP[count.index].id
  }
}


resource "azurerm_network_interface" "spokevm-nic" {
  location            = azurerm_resource_group.RG.location
  name                = "spokevm-nic"
  resource_group_name = azurerm_resource_group.RG.name
  ip_configuration {
    name                          = "ipconfig1"
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.spokevm-pip.id
    subnet_id                     = azurerm_virtual_network.spoke-vnet.subnet.*.id[0]
  }
  timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
  }
  
}
resource "azurerm_network_interface_application_gateway_backend_address_pool_association" "nic-assoc" {
  count                   = 2
  network_interface_id    = azurerm_network_interface.vnic[count.index].id
  ip_configuration_name   = "ipconfig${count.index}"
  backend_address_pool_id = azurerm_application_gateway.appgw1.backend_address_pool.*.id[0]
}

resource "azurerm_linux_virtual_machine" "webvm" {
  count                 = 2
  name                  = "vm-${count.index}"
  location              = azurerm_resource_group.RG.location
  resource_group_name   = azurerm_resource_group.RG.name
  network_interface_ids = [azurerm_network_interface.vnic[count.index].id]
  size                  = "Standard_B2ms"

  os_disk {    
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  admin_username                  = var.D-username
  admin_password                  = var.E-password
  disable_password_authentication = false
  
}

#Install Nginx
resource "azurerm_virtual_machine_extension" "vm_extension" {
  count                = 2
  name                 = "Nginx"
  virtual_machine_id   = azurerm_linux_virtual_machine.webvm[count.index].id
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.0"

  settings = <<SETTINGS
 {
  "commandToExecute": "sudo apt-get update && sudo apt-get install nginx -y && echo '<h1>NGINX webserver-${count.index} is running</h1>' > /var/www/html/index.html && sudo systemctl restart nginx"
 }
SETTINGS

}


resource "azurerm_windows_virtual_machine" "spokevm" {
  admin_password        = var.E-password
  admin_username        = var.D-username
  location              = azurerm_resource_group.RG.location
  name                  = "spokevm"
  network_interface_ids = [azurerm_network_interface.spokevm-nic.id]
  resource_group_name   = azurerm_resource_group.RG.name
  size                  = "Standard_B2ms"
  identity {
    type = "SystemAssigned"
  }
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }
  source_image_reference {
    offer     = "WindowsServer"
    publisher = "MicrosoftWindowsServer"
    sku       = "2022-datacenter-azure-edition"
    version   = "latest"
  }
  timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
  }
  
}

resource "azurerm_resource_group_template_deployment" "spokevmcert" {
  name                = "spokevmcert-deploy"
  resource_group_name = azurerm_resource_group.RG.name
  deployment_mode     = "Incremental"
  template_content = <<TEMPLATE
{
    "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {},
    "variables": {},
    "resources": [
      {
      "type": "Microsoft.Compute/virtualMachines/extensions",
      "apiVersion": "2020-06-01",
      "name": "spokevm/spokevmcert",
      "location": "${azurerm_windows_virtual_machine.spokevm.location}",
      "properties": {
        "publisher": "Microsoft.Compute",
        "type": "CustomScriptExtension",
        "typeHandlerVersion": "1.7",
        "autoUpgradeMinorVersion": true,
        "settings": {
          "commandToExecute": "[format('echo {0} > c:\\root.pem.base64 && powershell \"Set-Content -Path c:\\root.pem -Value ([Text.Encoding]::UTF8.GetString([convert]::FromBase64String((Get-Content -Path c:\\root.pem.base64))))\" && certutil -addstore root c:\\root.pem & powershell \"Add-Content -Path c:\\Windows\\System32\\drivers\\etc\\hosts -Value \"`n${azurerm_public_ip.appgw-pip.ip_address}`ttestcert.com\" -Force\"', reference(resourceId('Microsoft.Resources/deploymentScripts', 'createcerts'), '2020-10-01').outputs.rootca2)]"
          }
        }
      }
      
    
    ]
}
TEMPLATE
depends_on = [ azurerm_resource_group_template_deployment.secret ]
}
