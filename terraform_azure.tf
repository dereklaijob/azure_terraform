variable "resourcename" {
  default = "dlResourceGroup"
}

variable "arm_tenant_id" {
  default = ""
}

variable "arm_client_id" {
  default = ""
}

provider "azurerm" {
}


# Create a resource group if it doesn’t exist
resource "azurerm_resource_group" "dlterraformgroup" {
    name     = "dlResourceGroup"
    location = "westus2"

    tags {
        environment = "Terraform Demo"
    }
}

# Create virtual network
resource "azurerm_virtual_network" "dlterraformnetwork" {
    name                = "dlVnet"
    address_space       = ["10.0.0.0/16"]
    location            = "westus2"
    resource_group_name = "${azurerm_resource_group.dlterraformgroup.name}"

    tags {
        environment = "Terraform Demo"
    }
}

# Create subnet
resource "azurerm_subnet" "dlterraformsubnet" {
    name                 = "dlSubnet"
    resource_group_name  = "${azurerm_resource_group.dlterraformgroup.name}"
    virtual_network_name = "${azurerm_virtual_network.dlterraformnetwork.name}"
    address_prefix       = "10.0.1.0/24"
}

# Create public IPs
resource "azurerm_public_ip" "dlterraformpublicip" {
    name                         = "dlPublicIP"
    location                     = "westus2"
    resource_group_name          = "${azurerm_resource_group.dlterraformgroup.name}"
    public_ip_address_allocation = "dynamic"

    tags {
        environment = "Terraform Demo"
    }
}


# Create network interface
resource "azurerm_network_interface" "dlterraformnic" {
    name                      = "dlNIC"
    location                  = "westus2"
    resource_group_name       = "${azurerm_resource_group.dlterraformgroup.name}"
    network_security_group_id = "${azurerm_network_security_group.dlterraformnsg.id}"

    ip_configuration {
        name                          = "myNicConfiguration"
        subnet_id                     = "${azurerm_subnet.dlterraformsubnet.id}"
        private_ip_address_allocation = "dynamic"
        public_ip_address_id          = "${azurerm_public_ip.dlterraformpublicip.id}"
    }

    tags {
        environment = "Terraform Demo"
    }
}

# Generate random text for a unique storage account name
resource "random_id" "randomId" {
    keepers = {
        # Generate a new ID only when a new resource group is defined
        resource_group = "${azurerm_resource_group.dlterraformgroup.name}"
    }

    byte_length = 8
}

# Create storage account for boot diagnostics
resource "azurerm_storage_account" "dlstorageaccount" {
    name                        = "diag${random_id.randomId.hex}"
    resource_group_name         = "${azurerm_resource_group.dlterraformgroup.name}"
    location                    = "westus2"
    account_tier                = "Standard"
    account_replication_type    = "LRS"

    tags {
        environment = "Terraform Demo"
    }
}

# Create virtual machine
resource "azurerm_virtual_machine" "dlterraformvm" {
    name                  = "dlVM"
    location              = "westus2"
    resource_group_name   = "${azurerm_resource_group.dlterraformgroup.name}"
    network_interface_ids = ["${azurerm_network_interface.dlterraformnic.id}"]
    vm_size               = "Standard_DS1_v2"

    storage_os_disk {
        name              = "dlOsDisk"
        caching           = "ReadWrite"
        create_option     = "FromImage"
        managed_disk_type = "Premium_LRS"
    }

    storage_image_reference {
        publisher = "Canonical"
        offer     = "UbuntuServer"
        sku       = "16.04.0-LTS"
        version   = "latest"
    }

    os_profile {
        computer_name  = "dlvm"
        admin_username = "azureuser"
    }

    os_profile_linux_config {
        disable_password_authentication = true
        ssh_keys {
            path     = "/home/azureuser/.ssh/authorized_keys"
            key_data = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC3lVfsFx2Tzb4alNMqe8HHyBnjTAaU5DvWO7XO0DqPJndaIdsm6bcpXl5r2FCXIUA/ERw9s5j8xebO4gxEjqwaXEMNJjjB/YRlJpEU6YOBMLaIHBf5F5dzK0WHy/gYl+uVQk6eepIUh/X/L34hKt5gjCzXP4dNtMw03Zg9kdSb1AHBfo8UU0HXwNTbeBO6EBEp54vnpeFvnJV8bnplDZAUtInxWiz2jVVaHc7uD3n5xP/HLlACcbmAF+7fV3Fi7liGZDowOwjS3vXIFGC4v0nhpQSKCWPdqLS+Wmtab0EvSRKuayWadcQmzsNJWgj7bx/84jtTV2pdzgdZKXM8r13D ons"
        }
    }

    boot_diagnostics {
        enabled = "true"
        storage_uri = "${azurerm_storage_account.dlstorageaccount.primary_blob_endpoint}"
    }

    tags {
        environment = "Terraform Demo"
    }
}

resource "azurerm_metric_alertrule" "test" {
  name = "${azurerm_virtual_machine.dlterraformvm.name}-cpu"
  resource_group_name = "${azurerm_resource_group.dlterraformgroup.name}"
  location = "${azurerm_resource_group.dlterraformgroup.location}"

  description = "An alert rule to watch the metric Percentage CPU"

  enabled = true

  resource_id = "${azurerm_virtual_machine.dlterraformvm.id}"
  metric_name = "Percentage CPU"
  operator = "GreaterThan"
  threshold = 75
  aggregation = "Average"
  period = "PT5M"

  email_action {
    send_to_service_owners = false
    custom_emails = [
      "some.user@example.com",
    ]
  }

  webhook_action {
    service_uri = "https://example.com/some-url"
      properties = {
        severity = "incredible"
        acceptance_test = "true"
      }
  }
}

resource "azurerm_key_vault" "dltest" {
  name                = "dltestvault"
  location            = "WestUS2"
  resource_group_name = "${azurerm_resource_group.dlterraformgroup.name}"

  sku {
    name = "standard"
  }

  tenant_id = "${var.arm_tenant_id}"

  access_policy {
    tenant_id = "${var.arm_tenant_id}"
    object_id = "${var.arm_client_id}"

    key_permissions = [
      "get",
    ]

    secret_permissions = [
      "get",
    ]
  }

  enabled_for_disk_encryption = true

  tags {
    environment = "Production"
  }
}

resource "azurerm_eventhub_namespace" "dltest" {
  name                = "dlEventHubNamespace"
  location            = "${azurerm_resource_group.dlterraformgroup.location}"
  resource_group_name = "${azurerm_resource_group.dlterraformgroup.name}"
  sku                 = "Standard"
  capacity            = 1

  tags {
    environment = "Production"
  }
}

resource "azurerm_eventhub" "dltest" {
  name                = "acceptanceTestEventHub"
  namespace_name      = "${azurerm_eventhub_namespace.dltest.name}"
  resource_group_name = "${azurerm_resource_group.dlterraformgroup.name}"
  partition_count     = 2
  message_retention   = 1
}
