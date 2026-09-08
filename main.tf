terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.4.0"
    }
  }
}
provider "azurerm" {
  features {}
  subscription_id = "790aa1f8-6209-43c8-8546-2cbff23d845f"
}

# Create a resource group
resource "azurerm_resource_group" "wind-rg" {
  name     = "wind-rg"
  location = "East US"
}

# Create a virtual network
resource "azurerm_virtual_network" "wind-vnet" {
  name                = "wind-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = "East US"
  resource_group_name = azurerm_resource_group.wind-rg.name
}

# Create a subnet
resource "azurerm_subnet" "wind-subnet" {
  name                 = "wind-subnet"
  resource_group_name  = azurerm_resource_group.wind-rg.name
  virtual_network_name = azurerm_virtual_network.wind-vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

#create public ip
resource "azurerm_public_ip" "wind-public-ip" {
  name                = "wind-public-ip"
  location            = azurerm_resource_group.wind-rg.location
  resource_group_name = azurerm_resource_group.wind-rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

#create network security group
resource "azurerm_network_security_group" "wind-nsg" {
  name                = "wind-nsg"
  location            = azurerm_resource_group.wind-rg.location
  resource_group_name = azurerm_resource_group.wind-rg.name

  security_rule {
    name                       = "AllowSSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  #create network security group rule to allow HTTP traffic
  security_rule {
    name                       = "AllowHTTP"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

#create network interface
resource "azurerm_network_interface" "wind-nic" {
  name                = "wind-nic"
  location            = azurerm_resource_group.wind-rg.location
  resource_group_name = azurerm_resource_group.wind-rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.wind-subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.wind-public-ip.id
  }
}

#associate network security group with network interface
resource "azurerm_network_interface_security_group_association" "wind-nic-nsg-association" {
  network_interface_id      = azurerm_network_interface.wind-nic.id
  network_security_group_id = azurerm_network_security_group.wind-nsg.id
}

#create virtual machine
resource "azurerm_linux_virtual_machine" "wind-vm" {
  name                = "wind-vm"
  resource_group_name = azurerm_resource_group.wind-rg.name
  location            = azurerm_resource_group.wind-rg.location
  size                = "Standard_D2s_v3"
  admin_username      = "azureuser"
  network_interface_ids = [
    azurerm_network_interface.wind-nic.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  admin_ssh_key {
    username   = "azureuser"
    public_key = file("~/.ssh/id_rsa.pub")
  }
}

# Install and configure the web server on the existing VM.
resource "azurerm_virtual_machine_extension" "wind-nginx" {
  name                 = "install-nginx"
  virtual_machine_id   = azurerm_linux_virtual_machine.wind-vm.id
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.1"

  settings = jsonencode({
    commandToExecute = "sudo bash -c 'apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y nginx && mkdir -p /var/www/html && printf \"<html><body><h1>It works!</h1></body></html>\\n\" > /var/www/html/index.html && systemctl enable --now nginx'"
  })
}

#output the public IP address of the virtual machine
output "public_ip_address" {
  value = azurerm_public_ip.wind-public-ip.ip_address
}
