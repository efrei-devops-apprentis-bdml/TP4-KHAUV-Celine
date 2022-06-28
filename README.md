# TP4-KHAUV-Celine

## Pourquoi utiliser Terraform pour deployer des ressources sur le cloud plutôt que la CLI ou l'interface utilisateur


Les fournisseurs Azure Terraform nous permettent de gérer toute notre infrastructure Azure à l’aide d'une même syntaxe déclarative et de l’outil. 


Elle permet également de configurer des ressources Azure de manière reproductible et prévisible. Ainsi elle réduit le risque d’erreur humaine lors du déploiement et de la gestion et elle permet de déployer un même modèle plusieurs fois.
Elle réduit aussi le coût des environnements de développement et de test en permettant de les créer à la demande.


L’interface CLI Terraform permet aux utilisateurs de valider et d’afficher un aperçu des modifications d’infrastructure avant l’application du plan. On évite donc les changements innatendu et facilite la collaboration e comprennant plus vite quelles modifications ont été effectuées.


## Providers.tf
### azurerm 
Le provider Azure peut être utiliser pour configurer l'infrastructure dans Microsoft Azure à l'aide de l'API du Azure Resource Manager.


On passe en argument notre subscription ID

```terraform
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.0.0"
    }
  }
}

# Configure the Microsoft Azure Provider
provider "azurerm" {
  features {}

  subscription_id = "765266c6-9a23-4638-af32-dd1e32613047"
}
```

## Data.tf
### Recupération du ressource groupe, du réseau et du réseau préalablement créer sur Azure Cloud 

Le data source permet à Terraform d'utiliser des informations définies en dehors de Terraform ou par une autre configuration Terraform distincte ou modifiées par des fonctions.


Une source de données est accessible via un type spécial de ressource appelée ressource de données , déclarée à l'aide d'un databloc.
Un databloc demande à Terraform de lire à partir d'une source de données donnée (par exemple : "azurerm_resource_group") et d'exporter le résultat sous le nom local donné (toujours dans le même exemple, "tp4"). 

```terraform
data "azurerm_resource_group" "tp4" {
    name = "devops-TP2"
}

data "azurerm_virtual_network" "example-network" {
    name = "example-network"
    resource_group_name = data.azurerm_resource_group.tp4.name
} 

data "azurerm_subnet" "internal" {
    name = "internal"
    resource_group_name   =    data.azurerm_resource_group.tp4.name 
    virtual_network_name   =   data.azurerm_virtual_network.example-network.name 
} 
```

## Network.tf
### Création de la machine virtuelle et des autres ressources neccessaires au TP
Chaque bloc de ressources décrit un ou plusieurs objets d'infrastructure comme une machine virtuelle.


Ici, on crée une adresse IP publique et l'interface necessaire à notre machine virtuelle. Puis on crée une clé privée au format PEM (et OpenSSH) qui va nous servir pour nous connecter.

```terraform
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
```
Ici, on crée notre machine virtuelle avec tous ses paramètre comme le stockage qui doit être "Standard_D2s_v3". 


Pour assurer la connection; soit admin_password ou soit admin_ssh_key doit être spécifier. Dans notre cas, on utilise la clé privée précedemment créée.
```terraform
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
```
Ici, on crée un groupe de sécurité réseau et on le relie à notre réseau
Ce groupe de sécurité réseau contient une liste de règles de sécurité réseau. Les groupes de sécurité réseau permettent d'autoriser ou de refuser le trafic entrant ou sortant.
```terraform
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
```
## Output.tf
Les bloc output renvoient des informations sur notre infrastructure sur notre ligne de commande, et peuvent exposer des informations que d'autres configurations Terraform peuvent utiliser. 

Le paramètre "sensitive" doit être égale à true si la donner est sensible.
```terraform
output "resource_group_name" {
  value = data.azurerm_resource_group.tp4.name
}

output "public_ip_address" {
  value = azurerm_linux_virtual_machine.vm.public_ip_address
}

output "tls_private_key" {
  value     = tls_private_key.example_ssh.private_key_pem
  sensitive = true
}
```
Grâce aux informations renvoyé par les output, on peut faire : 
```bash
terraform output -raw tls_private_key > id_rsa
```
```bash
sudo ssh -i id_rsa devops@20.216.145.98 cat /etc/os-release
 ```
