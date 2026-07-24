terraform {
  required_version = ">= 1.9"

  required_providers {
    pagerduty = {
      source  = "PagerDuty/pagerduty"
      version = "~> 3.17" # 3.17 is the first version that supports native Jira Cloud integration
    }

    # Key Vault secret data sources only: this module reads the Jira integration
    # profile secrets from an existing vault. It creates no Azure resources.
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}
