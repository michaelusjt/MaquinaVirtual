terraform {
   required_version = ">= 0.13"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 2.46.0"
    }
  }
}

provider "azurerm" {
  skip_provider_registration = true
  features {
}
}

resource "azurerm_resource_group" "example" {
     name     = "MySqlTerraform"
     location = "eastus"
}


resource "azurerm_public_ip" "rede_ip" {
  name                         = "acceptanceTestPublicIp1"
  resource_group_name          = azurerm_resource_group.example.name
  location                     = azurerm_resource_group.example.location
  allocation_method   = "Static"

  tags = {
    environment = "Production"
  }
}



resource "azurerm_network_interface" "rede_interface" {
  name                = "example-nic"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name

  ip_configuration {
    name                          = "Redeinterface"
    subnet_id                     = azurerm_subnet.Terraform_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id = azurerm_public_ip.rede_ip.id
  }
}

resource "azurerm_network_interface_security_group_association" "rede_placa" {
  network_interface_id      = azurerm_network_interface.rede_interface.id
  network_security_group_id = azurerm_network_security_group.rede_security.id
}

resource "azurerm_virtual_machine" "rede_maquina" {
  name                  = "maquina-vm"
  location              = azurerm_resource_group.example.location
  resource_group_name   = azurerm_resource_group.example.name
  network_interface_ids = [azurerm_network_interface.rede_interface.id]
  vm_size               = "Standard_DS1_v2"


  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }
  storage_os_disk {
    name              = "myosdisk1"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }
  os_profile {
    computer_name  = "hostname"
    admin_username = "testadmin"
    admin_password = "Password1234!"
  }
  os_profile_linux_config {
    disable_password_authentication = false
  }
  tags = {
    environment = "staging"
  }
}

data "azurerm_public_ip" "ip-db" {
  name                = azurerm_public_ip.rede_ip.name
  resource_group_name = azurerm_resource_group.example.name
}

resource "time_sleep" "wait_30_seconds_db" {
  depends_on = [azurerm_virtual_machine.rede_maquina]
  create_duration = "30s"
}
resource "null_resource" "uploadMYSQL" {
    provisioner "file" {
        connection {
            type = "ssh"
            user = "testadmin"
            password = "Password1234!"
            host = data.azurerm_public_ip.ip-db.ip_address
        }
        source = "mysql"
        destination = "/home/testadmin"
    }

    depends_on = [ time_sleep.wait_30_seconds_db ]
}
resource "null_resource" "deployMYSQL" {
    triggers = {
        order = null_resource.uploadMYSQL.id
    }
    provisioner "remote-exec" {
        connection {
            type = "ssh"
            user = "testadmin"
            password = "Password1234!"
            host = data.azurerm_public_ip.ip-db.ip_address
        }
        inline = [
            "sudo apt-get update",
            "sudo apt-get install -y mysql-server-5.7",
            "sudo mysql < /home/testadmin/mysql/script/user.sql",
            #"sudo mysql < /home/testadmin/mysql/script/schema.sql",
            #"sudo mysql < /home/testadmin/mysql/script/data.sql",
            "sudo cp -f /home/testadmin/mysql/mysqld.cnf /etc/mysql/mysql.conf.d/mysqld.cnf",
            "sudo service mysql restart",
            "sleep 20",]
}
}