# Output contract: the datadog_integrations map and pagerduty_services list are a
# published interface shared with the AWS sibling module. Client repos consume
# them as drop-ins, so their keys and shape must not drift.

mock_provider "pagerduty" {
  source = "./tests/setup-pagerduty"
}

mock_provider "azurerm" {
  source = "./tests/setup"
}

override_data {
  target = data.azurerm_key_vault_secret.jira_account["create-issue-on-incident-trigger"]
  values = { value = "true" }
}
override_data {
  target = data.azurerm_key_vault_secret.jira_compliance["create-issue-on-incident-trigger"]
  values = { value = "true" }
}
override_data {
  target = data.azurerm_key_vault_secret.jira_cost["create-issue-on-incident-trigger"]
  values = { value = "true" }
}
override_data {
  target = data.azurerm_key_vault_secret.jira_security["create-issue-on-incident-trigger"]
  values = { value = "true" }
}
override_data {
  target = data.azurerm_key_vault_secret.jira_account["custom-jira-fields"]
  values = { value = "[]" }
}
override_data {
  target = data.azurerm_key_vault_secret.jira_account["custom-fixed-fields"]
  values = { value = "[]" }
}
override_data {
  target = data.azurerm_key_vault_secret.jira_compliance["custom-jira-fields"]
  values = { value = "[]" }
}
override_data {
  target = data.azurerm_key_vault_secret.jira_compliance["custom-fixed-fields"]
  values = { value = "[]" }
}
override_data {
  target = data.azurerm_key_vault_secret.jira_cost["custom-jira-fields"]
  values = { value = "[]" }
}
override_data {
  target = data.azurerm_key_vault_secret.jira_cost["custom-fixed-fields"]
  values = { value = "[]" }
}
override_data {
  target = data.azurerm_key_vault_secret.jira_security["custom-jira-fields"]
  values = { value = "[]" }
}
override_data {
  target = data.azurerm_key_vault_secret.jira_security["custom-fixed-fields"]
  values = { value = "[]" }
}

run "output_contract" {
  command = plan

  variables {
    org_name             = "TestOrg"
    customer_name        = "TestCustomer"
    key_vault_id         = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.KeyVault/vaults/test-vault"
    jira_organization_id = "test-org-id"
  }

  # The map is keyed by exactly the four concerns (keys() returns them sorted).
  assert {
    condition     = keys(output.datadog_integrations) == ["account", "compliance", "cost", "security"]
    error_message = "datadog_integrations must be keyed account/compliance/cost/security"
  }

  # Every entry exposes a name and a key.
  assert {
    condition     = alltrue([for k, v in output.datadog_integrations : can(v.name) && can(v.key)])
    error_message = "each datadog_integrations entry must expose name and key"
  }

  # The name in the map matches the underlying service name.
  assert {
    condition     = output.datadog_integrations["account"].name == pagerduty_service.account.name
    error_message = "the account integration name should match the account service name"
  }

  assert {
    condition     = output.datadog_integrations["security"].name == pagerduty_service.security.name
    error_message = "the security integration name should match the security service name"
  }

  # The services list carries all four service ids.
  assert {
    condition     = length(output.pagerduty_services) == 4
    error_message = "pagerduty_services should list all four service ids"
  }

  # The per-concern service-name and mention outputs are wired.
  assert {
    condition     = output.account_service_name == "TestOrg Account Notifications (Azure - TestCustomer)"
    error_message = "account_service_name output should match the account service name"
  }

  assert {
    condition     = output.account_datadog_mention == "@pagerduty-TestOrgAccountNotificationsAzure-TestCustomer"
    error_message = "account_datadog_mention should strip brackets, parens and spaces from the service name"
  }
}
