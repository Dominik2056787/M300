terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

provider "azurerm" {
  features {}
  resource_provider_registrations = "none"
  subscription_id = "5d568cf7-9b58-4fc3-b8e6-0abe7acd08dd"
}

# AWS EC2 Instanz
resource "aws_instance" "fussball_server" {
  ami           = "ami-0c7217cdde317cfec"
  instance_type = "t3.medium"

  tags = {
    Name    = "fussball-dashboard"
    Projekt = "M300"
  }
}

# Azure Resource Group
resource "azurerm_resource_group" "m300" {
  name     = "m300-fussball-rg"
  location = "East US"
}
#
# Azure Virtual Network
resource "azurerm_virtual_network" "m300" {
  name                = "m300-network"
  address_space       = ["10.0.0.0/16"]
  location            = "switzerlandnorth"
  resource_group_name = azurerm_resource_group.m300.name
}

# Azure Subnet
resource "azurerm_subnet" "m300" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.m300.name
  virtual_network_name = azurerm_virtual_network.m300.name
  address_prefixes     = ["10.0.1.0/24"]
}
#
## Azure Network Interface
#resource "azurerm_network_interface" "m300" {
#  name                = "m300-nic"
#  location            = azurerm_resource_group.m300.location
#  resource_group_name = azurerm_resource_group.m300.name
#
#  ip_configuration {
#    name                          = "internal"
#    subnet_id                     = azurerm_subnet.m300.id
#    private_ip_address_allocation = "Dynamic"
#  }
#}

# Azure Storage Account (Backup für Disaster Recovery)
resource "azurerm_storage_account" "m300_backup" {
  name                     = "m300backuphausammann"
  resource_group_name      = azurerm_resource_group.m300.name
  location                 = "switzerlandnorth"
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags = {
    Projekt = "M300"
    Zweck   = "Disaster Recovery Backup"
  }
}

# Container innerhalb des Storage Accounts (wie ein Ordner)
resource "azurerm_storage_container" "backup_container" {
  name                  = "m300-backups"
  storage_account_id   = azurerm_storage_account.m300_backup.id
  container_access_type = "private"
}
#
## Azure Key Vault (Secrets Management, Alternative zu Storage Account)
#resource "azurerm_key_vault" "m300_vault" {
#  name                = "m300-fussball-kv"
#  resource_group_name = azurerm_resource_group.m300.name
#  location            = azurerm_resource_group.m300.location
#  tenant_id           = "cdd91ffe-4775-4b3a-8a2c-f76b00a3d47e"
#  sku_name            = "standard"
#
#  tags = {
#    Projekt = "M300"
#    Zweck   = "Secrets Management Multi-Cloud"
#  }
#}

# Azure Public IP für die VM
resource "azurerm_public_ip" "m300_vm_ip" {
  name                = "m300-vm-ip"
  resource_group_name = azurerm_resource_group.m300.name
  location            = azurerm_virtual_network.m300.location
  allocation_method   = "Static"
  sku                 = "Standard"
}

# Network Security Group (Firewall-Regeln)
resource "azurerm_network_security_group" "m300_nsg" {
  name                = "m300-nsg"
  location            = azurerm_virtual_network.m300.location
  resource_group_name = azurerm_resource_group.m300.name

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Frontend"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8080"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Backend"
    priority                   = 1003
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5000"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Azure Network Interface für die VM
resource "azurerm_network_interface" "m300_vm_nic" {
  name                = "m300-vm-nic"
  location            = azurerm_virtual_network.m300.location
  resource_group_name = azurerm_resource_group.m300.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.m300.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.m300_vm_ip.id
  }
}

# NSG mit NIC verbinden
resource "azurerm_network_interface_security_group_association" "m300_nsg_assoc" {
  network_interface_id     = azurerm_network_interface.m300_vm_nic.id
  network_security_group_id = azurerm_network_security_group.m300_nsg.id
}

# Azure Linux VM (Migrationsziel von AWS EC2)
resource "azurerm_linux_virtual_machine" "m300_vm" {
  name                = "m300-fussball-vm"
  resource_group_name = azurerm_resource_group.m300.name
  location            = azurerm_virtual_network.m300.location
  size                = "Standard_B2s"
  admin_username      = "azureuser"
  network_interface_ids = [azurerm_network_interface.m300_vm_nic.id]

  admin_ssh_key {
    username   = "azureuser"
    public_key = file("/home/ubuntu/.ssh/azure_key.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = 30
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  tags = {
    Projekt = "M300"
    Zweck   = "Migration von AWS EC2"
  }
}
