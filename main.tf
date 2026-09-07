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

terraform {
  backend "azurerm" {
    resource_group_name  = "ext-rg"
    storage_account_name = "extrastorage26"
    container_name       = "tfstate"
    key                  = "terraform.tfstate"
  }
  required_version = ">= 1.0.0"
}

# Create a resource group
resource "azurerm_resource_group" "extra-rg" {
  name     = "extra-rg"
  location = "East US"
}

# Create a virtual network
resource "azurerm_virtual_network" "extra-vnet" {
  resource_group_name = azurerm_resource_group.extra-rg.name
  name                = "extra-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.extra-rg.location
}

# Create a subnet
resource "azurerm_subnet" "extra-subnet" {
  name                 = "extra-subnet"
  resource_group_name  = azurerm_resource_group.extra-rg.name
  virtual_network_name = azurerm_virtual_network.extra-vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Create a network security group
resource "azurerm_network_security_group" "extra-nsg" {
  name                = "extra-nsg"
  location            = azurerm_resource_group.extra-rg.location
  resource_group_name = azurerm_resource_group.extra-rg.name

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

#create public IP
resource "azurerm_public_ip" "extra-pip" {
  name                = "extra-pip"
  location            = azurerm_resource_group.extra-rg.location
  resource_group_name = azurerm_resource_group.extra-rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

#create network interface
resource "azurerm_network_interface" "extra-nic" {
  name                = "extra-nic"
  location            = azurerm_resource_group.extra-rg.location
  resource_group_name = azurerm_resource_group.extra-rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.extra-subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.extra-pip.id
  }
}

#associate NSG with NIC
resource "azurerm_network_interface_security_group_association" "extra-nic-nsg-association" {
  network_interface_id      = azurerm_network_interface.extra-nic.id
  network_security_group_id = azurerm_network_security_group.extra-nsg.id
}

#create virtual machine
resource "azurerm_linux_virtual_machine" "extra-vm" {
  name                = "extra-vm"
  resource_group_name = azurerm_resource_group.extra-rg.name
  location            = azurerm_resource_group.extra-rg.location
  size                = "Standard_D2s_v3"
  admin_username      = "adminuser"
  network_interface_ids = [
    azurerm_network_interface.extra-nic.id,
  ]

  admin_ssh_key {
    username   = "adminuser"
    public_key = file("~/.ssh/id_rsa.pub")
  }

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
}

# Output the public IP address of the virtual machine
output "extra_vm_public_ip" {
  value = azurerm_public_ip.extra-pip.ip_address
}