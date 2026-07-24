variable "subscription_id" {
  description = "Azure subscription id used to satisfy the azurerm v4 provider block. No Azure resources are created."
  type        = string
  default     = "00000000-0000-0000-0000-000000000000"
}
