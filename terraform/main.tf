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
  subscription_id = "995865ce-57e4-44a8-bd4c-f5bbc723bf0f"
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

# Azure Virtual Network
resource "azurerm_virtual_network" "m300" {
  name                = "m300-network"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.m300.location
  resource_group_name = azurerm_resource_group.m300.name
}

# Azure Subnet
resource "azurerm_subnet" "m300" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.m300.name
  virtual_network_name = azurerm_virtual_network.m300.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Azure Network Interface
resource "azurerm_network_interface" "m300" {
  name                = "m300-nic"
  location            = azurerm_resource_group.m300.location
  resource_group_name = azurerm_resource_group.m300.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.m300.id
    private_ip_address_allocation = "Dynamic"
  }
}
