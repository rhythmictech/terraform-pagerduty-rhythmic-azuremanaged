terraform {
  required_version = ">= 1.9"

  required_providers {
    pagerduty = {
      source  = "PagerDuty/pagerduty"
      version = "~> 3.17"
    }
  }
}

provider "pagerduty" {}

# Minimal invocation: four notification services (account, compliance, cost,
# security), the umbrella business service, the Datadog integrations and the
# Jira mapping rules. The escalation policies, the customer business service and
# the Jira Cloud account mapping must already exist in PagerDuty (see the module
# README). One custom suppression rule is shown to illustrate the input shape.
#
# The Jira profile values come from var.jira_profiles (variables.tf) so the
# example stays self-contained. In a real client repository they are read from
# wherever the operator keeps them; the README shows the AWS SSM wiring.
module "azure_managed_services" {
  source = "../../"

  org_name             = "ExampleOrg"
  customer_name        = "ExampleCustomer"
  jira_organization_id = "00000000-0000-0000-0000-000000000000"

  jira_profiles = var.jira_profiles

  account_suppression_rules = [
    {
      label     = "Mute a known-noisy signal"
      condition = "event.custom_details.body matches part 'ExampleNoise'"
    }
  ]
}
