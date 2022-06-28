resource   "azurerm_public_ip"   "publicip"   { 
   name   =   "publicip-20180417" 
   location   =   var.region
   resource_group_name   =   data.azurerm_resource_group.tp4.name 
   allocation_method   =   "Dynamic" 
   sku   =   "Basic" 
 } 

resource "azurerm_network_interface" "interface" {
  name                = "interface-20180417"
  resource_group_name = data.azurerm_resource_group.tp4.name
  location            = var.region

  ip_configuration {
    name                          = "publicip"
    subnet_id                     = data.azurerm_subnet.internal.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id   =   azurerm_public_ip.publicip.id 
  }
}

resource "tls_private_key" "example_ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "azurerm_linux_virtual_machine" "vm" {
  name                            = "devops-20180417"
  resource_group_name             = data.azurerm_resource_group.tp4.name
  location                        = var.region
  size                            = "Standard_D2s_v3"
  admin_username                  = "devops"
  network_interface_ids = [
    azurerm_network_interface.interface.id,
  ]

  admin_ssh_key {
    username   = "devops"
    public_key = tls_private_key.example_ssh.public_key_openssh
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }

  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }
}

resource "azurerm_network_security_group" "ubuntu-security" {
  name                = "ubuntu-security-20180417"
  location            = var.region
  resource_group_name = data.azurerm_resource_group.tp4.name

  security_rule {
    name                       = "ssh"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
    environment = "Production"
  }
}

resource "azurerm_network_interface_security_group_association" "ubuntu" {
    network_interface_id      = azurerm_network_interface.interface.id
    network_security_group_id = azurerm_network_security_group.ubuntu-security.id
}