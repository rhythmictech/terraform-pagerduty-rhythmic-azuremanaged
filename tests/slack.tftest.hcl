# Slack wiring: with a workspace and all three channels set, each concern gets a
# Slack connection. Account and cost both route to the customer-success channel;
# compliance and security route to their own.

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

run "all_channels_wired" {
  command = plan

  variables {
    org_name             = "TestOrg"
    customer_name        = "TestCustomer"
    key_vault_id         = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.KeyVault/vaults/test-vault"
    jira_organization_id = "test-org-id"

    slack_workspace_id                  = "W-TEST"
    slack_customer_success_team_channel = "C-CUSTOMER-SUCCESS"
    slack_compliance_team_channel       = "C-COMPLIANCE"
    slack_security_team_channel         = "C-SECURITY"
  }

  # One connection per concern.
  assert {
    condition     = length(pagerduty_slack_connection.account) == 1 && length(pagerduty_slack_connection.compliance) == 1 && length(pagerduty_slack_connection.cost) == 1 && length(pagerduty_slack_connection.security) == 1
    error_message = "every concern should get one Slack connection when its channel is set"
  }

  # Account and cost share the customer-success channel.
  assert {
    condition     = pagerduty_slack_connection.account[0].channel_id == "C-CUSTOMER-SUCCESS" && pagerduty_slack_connection.cost[0].channel_id == "C-CUSTOMER-SUCCESS"
    error_message = "account and cost should route to the customer-success channel"
  }

  # Compliance and security route to their own channels.
  assert {
    condition     = pagerduty_slack_connection.compliance[0].channel_id == "C-COMPLIANCE"
    error_message = "compliance should route to the compliance channel"
  }

  assert {
    condition     = pagerduty_slack_connection.security[0].channel_id == "C-SECURITY"
    error_message = "security should route to the security channel"
  }

  # The workspace id flows through.
  assert {
    condition     = pagerduty_slack_connection.account[0].workspace_id == "W-TEST"
    error_message = "the Slack workspace id should flow through"
  }

  # The full twelve-event notification config is present with all priorities.
  assert {
    condition     = length(pagerduty_slack_connection.account[0].config[0].events) == 12
    error_message = "the Slack connection should subscribe to the full twelve-event list"
  }

  assert {
    condition     = contains(pagerduty_slack_connection.security[0].config[0].priorities, "*")
    error_message = "the Slack connection should apply to all priorities"
  }
}

# With no channels set, no Slack connections are created (mirrors the defaults
# path, asserted here alongside the wired case for a focused contrast).
run "no_channels" {
  command = plan

  variables {
    org_name             = "TestOrg"
    customer_name        = "TestCustomer"
    key_vault_id         = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.KeyVault/vaults/test-vault"
    jira_organization_id = "test-org-id"
  }

  assert {
    condition     = length(pagerduty_slack_connection.account) == 0 && length(pagerduty_slack_connection.security) == 0
    error_message = "no channels means no Slack connections"
  }
}
