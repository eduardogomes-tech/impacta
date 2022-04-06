terraform {
  required_version = ">= 0.13"

  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = ">= 2.26"
    }
  }
}

provider "azurerm" {
  skip_provider_registration = true
  features {
  }
}

resource "azurerm_resource_group" "rg-atividade-terraform" {
  name     = "atividade-terraform"
  location = "West Europe"
}

resource "azurerm_virtual_network" "vnet-atividade-terraform" {
  name                = "vnet-atividade-terraform"
  resource_group_name = azurerm_resource_group.rg-atividade-terraform.name
  location            = azurerm_resource_group.rg-atividade-terraform.location
  address_space       = ["10.0.0.0/16"]

}

 resource "azurerm_subnet" "sub-atividade-terraform" {
  name                 = "sub-atividade-terraform"
  resource_group_name = azurerm_resource_group.rg-atividade-terraform.name
  virtual_network_name = azurerm_virtual_network.vnet-atividade-terraform.name
  address_prefixes     = ["10.0.1.0/24"]
  
}

resource "azurerm_public_ip" "ip-atividade-terraform" {
  name                = "ip-atividade-terraform"
  resource_group_name = azurerm_resource_group.rg-atividade-terraform.name
  location            = azurerm_resource_group.rg-atividade-terraform.location
  allocation_method   = "Static"

}

resource "azurerm_network_security_group" "nsg-atividade-terraform" {
  name                = "nsg-atividade-terraform"
  resource_group_name = azurerm_resource_group.rg-atividade-terraform.name
  location            = azurerm_resource_group.rg-atividade-terraform.location

  security_rule {
    name                       = "SSH"
    priority                   = 1010
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "web"
    priority                   = 1003
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface" "nic-atividade-terraform" {
  name                = "nic-atividade-terraform"
  resource_group_name = azurerm_resource_group.rg-atividade-terraform.name
  location            = azurerm_resource_group.rg-atividade-terraform.location

  ip_configuration {
    name                            = "ip-atividade-terraform"
    subnet_id                       = azurerm_subnet.sub-atividade-terraform.id
    private_ip_address_allocation   = "Dynamic"
    public_ip_address_id            = azurerm_public_ip.ip-atividade-terraform.id
  }
  
}

resource "azurerm_network_interface_security_group_association" "nic-nsg-atividade-terraform" {
  network_interface_id      = azurerm_network_interface.nic-atividade-terraform.id
  network_security_group_id = azurerm_network_security_group.nsg-atividade-terraform.id
}

resource "azurerm_virtual_machine" "vm-atividade-terraform" {
  name                  = "vm-atividade-terraform"
  resource_group_name = azurerm_resource_group.rg-atividade-terraform.name
  location            = azurerm_resource_group.rg-atividade-terraform.location
  network_interface_ids = [azurerm_network_interface.nic-atividade-terraform.id]
  vm_size               = "Standard_DS1_v2"

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }

  storage_os_disk {
    name              = "myosdisk-atividade-terraform"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = "atividade-terraform"
    admin_username = "myuser"
    admin_password = "P@ssword8080"
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }
  
  tags = {
    projeto = "Atividade Terraform"
  }
}

data "azurerm_public_ip" "ip-atividade-terraform"{
    name = azurerm_public_ip.ip-atividade-terraform.name
    resource_group_name = azurerm_resource_group.rg-atividade-terraform.name
}

resource "null_resource" "install-apache" {
  connection {
    type = "ssh"
    host = data.azurerm_public_ip.ip-atividade-terraform.ip_address
    user = "myuser"
    password = "P@ssword8080"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt update",
      "sudo apt install -y apache2",
    ]
  }

  depends_on = [
    azurerm_virtual_machine.vm-atividade-terraform
  ]
}
