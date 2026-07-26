terraform {
  required_version = ">= 1.9"

  required_providers {
    pagerduty = {
      source  = "PagerDuty/pagerduty"
      version = "~> 3.17"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "pagerduty" {}

# azurerm v4 makes subscription_id mandatory in the provider block. The module
# only reads Key Vault secrets, so no Azure resources are created here.
provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

# Minimal invocation: four notification services (account, compliance, cost,
# security), the umbrella business service, the Datadog integrations and the
# Jira mapping rules. The escalation policies, the customer business service and
# the Key Vault secrets must already exist (see the module README). One custom
# suppression rule is shown to illustrate the input shape.
module "azure_managed_services" {
  source = "../../"

  org_name             = "ExampleOrg"
  customer_name        = "ExampleCustomer"
  jira_organization_id = "00000000-0000-0000-0000-000000000000"

  # The vault holding the jira-<profile>-<param> secrets. It must already exist
  # and be populated by the onboarding runbook.
  key_vault_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-example/providers/Microsoft.KeyVault/vaults/example-vault"

  account_suppression_rules = [
    {
      label     = "Mute a known-noisy signal"
      condition = "event.custom_details.body matches part 'ExampleNoise'"
    }
  ]
}
