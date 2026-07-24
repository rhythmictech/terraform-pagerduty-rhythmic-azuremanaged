# Jira integration profile names become Key Vault secret names, which allow only
# letters, numbers and dashes. Underscores and slashes must be rejected by the
# variable validation. The data-source overrides keep the rest of the plan clean
# so the only surfaced failure is the expected variable validation.

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

run "underscore_rejected" {
  command = plan

  variables {
    org_name             = "TestOrg"
    customer_name        = "TestCustomer"
    key_vault_id         = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.KeyVault/vaults/test-vault"
    jira_organization_id = "test-org-id"

    account_jira_integration_profile = "noc_prod"
  }

  expect_failures = [
    var.account_jira_integration_profile,
  ]
}

run "slash_rejected" {
  command = plan

  variables {
    org_name             = "TestOrg"
    customer_name        = "TestCustomer"
    key_vault_id         = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.KeyVault/vaults/test-vault"
    jira_organization_id = "test-org-id"

    compliance_jira_integration_profile = "NOC/prod"
  }

  expect_failures = [
    var.compliance_jira_integration_profile,
  ]
}
