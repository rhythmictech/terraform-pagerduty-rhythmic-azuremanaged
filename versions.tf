terraform {
  required_version = ">= 1.9"

  required_providers {
    # PagerDuty is the only provider. The module touches no Azure resource and
    # reads no secret store: the Jira profile values arrive through
    # var.jira_profiles, so it needs nothing from the azurerm provider.
    pagerduty = {
      source  = "PagerDuty/pagerduty"
      version = "~> 3.17" # 3.17 is the first version that supports native Jira Cloud integration
    }
  }
}
