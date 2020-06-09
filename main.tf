# Configure the Azure Provider
provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "demo" {
  name     = "DemoResourceGroup"
  location = var.location
}

resource "azurerm_network_security_group" "demo" {
  name                = "Demo"
  location            = azurerm_resource_group.demo.location
  resource_group_name = azurerm_resource_group.demo.name

  security_rule {
    name                       = "ssh"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "0.0.0.0/0"
    destination_address_prefix = "10.0.0.0/16"
  }

  security_rule {
    name                       = "rdp"
    priority                   = 101
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "0.0.0.0/0"
    destination_address_prefix = "10.0.0.0/16"
  }

  security_rule {
    name                       = "http"
    priority                   = 102
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "0.0.0.0/0"
    destination_address_prefix = "10.0.0.0/16"
  }
}

resource "azurerm_dns_zone" "demo" {
  name                = "demo.local"
  resource_group_name = azurerm_resource_group.demo.name
}

resource "azurerm_virtual_network" "demo" {
  name                = "Demo"
  location            = azurerm_resource_group.demo.location
  resource_group_name = azurerm_resource_group.demo.name
  address_space       = ["10.0.0.0/16"]

  tags = {
    environment = "Demo"
  }
}

resource "azurerm_subnet" "web" {
  name                 = "web"
  resource_group_name  = azurerm_resource_group.demo.name
  virtual_network_name = azurerm_virtual_network.demo.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_subnet_network_security_group_association" "web" {
  subnet_id                 = azurerm_subnet.web.id
  network_security_group_id = azurerm_network_security_group.demo.id
}

resource "azurerm_subnet" "mgmt" {
  name                 = "mgmt"
  resource_group_name  = azurerm_resource_group.demo.name
  virtual_network_name = azurerm_virtual_network.demo.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_subnet_network_security_group_association" "mgmt" {
  subnet_id                 = azurerm_subnet.mgmt.id
  network_security_group_id = azurerm_network_security_group.demo.id
}

resource "azurerm_network_interface" "web-01" {
  name                = "web-01"
  location            = azurerm_resource_group.demo.location
  resource_group_name = azurerm_resource_group.demo.name

  ip_configuration {
    name                          = "web-01"
    subnet_id                     = azurerm_subnet.web.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_dns_a_record" "web-01" {
  name                = "web-01"
  zone_name           = azurerm_dns_zone.demo.name
  resource_group_name = azurerm_resource_group.demo.name
  ttl                 = 300
  records             = ["${azurerm_network_interface.web-01.*.private_ip_address[0]}"]
}

resource "azurerm_virtual_machine" "web-01" {
  name                             = "web-01"
  location                         = azurerm_resource_group.demo.location
  resource_group_name              = azurerm_resource_group.demo.name
  network_interface_ids            = ["${azurerm_network_interface.web-01.id}"]
  vm_size                          = "Standard_D2s_v3"
  delete_os_disk_on_termination    = true
  delete_data_disks_on_termination = true

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }
  storage_os_disk {
    name              = "web-01-os"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }
  os_profile {
    computer_name  = "web-01"
    admin_username = var.admin_username
    admin_password = var.admin_password
    custom_data    = file("./scripts/cloud-config.txt")
  }
  os_profile_linux_config {
    disable_password_authentication = false
  }
  tags = {
    environment = "Demo"
  }
}

resource "azurerm_network_interface" "mgmt-01" {
  name                = "mgmt-01"
  location            = azurerm_resource_group.demo.location
  resource_group_name = azurerm_resource_group.demo.name

  ip_configuration {
    name                          = "mgmt-01"
    subnet_id                     = azurerm_subnet.mgmt.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.mgmt-01.id
  }
}

resource "azurerm_dns_a_record" "mgmt-01" {
  name                = "mgmt-01"
  zone_name           = azurerm_dns_zone.demo.name
  resource_group_name = azurerm_resource_group.demo.name
  ttl                 = 300
  records             = ["${azurerm_network_interface.mgmt-01.*.private_ip_address[0]}"]
}

resource "azurerm_public_ip" "mgmt-01" {
  name                = "mgmt-01"
  location            = var.location
  resource_group_name = azurerm_resource_group.demo.name
  allocation_method   = "Dynamic"

  tags = {
    environment = "Demo"
  }
}

resource "azurerm_virtual_machine" "mgmt-01" {
  name                          = "mgmt-01"
  location                      = azurerm_resource_group.demo.location
  resource_group_name           = azurerm_resource_group.demo.name
  network_interface_ids         = ["${azurerm_network_interface.mgmt-01.id}"]
  vm_size                       = "Standard_B2s"
  delete_os_disk_on_termination = true

  storage_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }

  storage_os_disk {
    name              = "mgmt-01-os"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = "mgmt-01"
    admin_username = var.admin_username
    admin_password = var.admin_password
    custom_data    = file("./scripts/windows_setup.ps1")
  }

  os_profile_windows_config {
    # enable_automatic_upgrades = true

    additional_unattend_config {
      pass         = "oobeSystem"
      component    = "Microsoft-Windows-Shell-Setup"
      setting_name = "FirstLogonCommands"
      content      = file("./scripts/FirstLogonCommands.xml")
    }
  }

  tags = {
    environment = "Demo"
  }
}

resource "azurerm_postgresql_server" "database-01" {
  name                = "demo-database-16055"
  location            = azurerm_resource_group.demo.location
  resource_group_name = azurerm_resource_group.demo.name

  sku_name = "B_Gen5_2"

  storage_mb            = 5120
  backup_retention_days = 7

  administrator_login          = var.admin_username
  administrator_login_password = var.admin_password
  version                      = "9.6"
  ssl_enforcement_enabled      = true
}

resource "azurerm_postgresql_database" "database-01" {
  name                = "demodb"
  resource_group_name = azurerm_resource_group.demo.name
  server_name         = azurerm_postgresql_server.database-01.name
  charset             = "UTF8"
  collation           = "English_United States.1252"
}