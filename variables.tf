variable "location" {
  type = string
  description = "The Azure location where all resources in this example should be created"
  default     = "East US"
}

variable "azure_instance_username" {
  type = string
  description = " Azure Instance login username"
}
variable "azure_instance_password" {
  type = string
  description = " Azure Instance login password"
}
