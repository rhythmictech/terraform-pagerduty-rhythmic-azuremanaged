locals {
  # Key Vault secret name suffixes, one per Jira integration profile parameter.
  # Key Vault secret names allow only [0-9a-zA-Z-], so the underscore-delimited
  # parameter names become dash-delimited (e.g. account_mapping_name ->
  # account-mapping-name). Each secret is named "jira-<profile>-<suffix>".
  jira_secret_names = [
    "account-mapping-name", "project", "project-name", "issue-type",
    "issue-status-open", "issue-status-acknowledged", "issue-status-resolved",
    "sync-notes-user", "create-issue-on-incident-trigger",
    "custom-jira-fields", "custom-fixed-fields",
  ]
}

########################################
# Jira parameters - Account
########################################
data "azurerm_key_vault_secret" "jira_account" {
  for_each = toset(local.jira_secret_names)

  name         = "jira-${var.account_jira_integration_profile}-${each.key}"
  key_vault_id = var.key_vault_id
}

########################################
# Jira parameters - Compliance
########################################
data "azurerm_key_vault_secret" "jira_compliance" {
  for_each = toset(local.jira_secret_names)

  name         = "jira-${var.compliance_jira_integration_profile}-${each.key}"
  key_vault_id = var.key_vault_id
}

########################################
# Jira parameters - Cost
########################################
data "azurerm_key_vault_secret" "jira_cost" {
  for_each = toset(local.jira_secret_names)

  name         = "jira-${var.cost_jira_integration_profile}-${each.key}"
  key_vault_id = var.key_vault_id
}

########################################
# Jira parameters - Security
########################################
data "azurerm_key_vault_secret" "jira_security" {
  for_each = toset(local.jira_secret_names)

  name         = "jira-${var.security_jira_integration_profile}-${each.key}"
  key_vault_id = var.key_vault_id
}

########################################
# PagerDuty parameters
########################################
data "pagerduty_vendor" "datadog" {
  name = "Datadog"
}

data "pagerduty_business_service" "customer" {
  name = var.customer_name
}

data "pagerduty_team" "customer_success" {
  name = "Customer Success Team"
}

data "pagerduty_jira_cloud_account_mapping" "account" {
  subdomain = data.azurerm_key_vault_secret.jira_account["account-mapping-name"].value
}

data "pagerduty_jira_cloud_account_mapping" "compliance" {
  subdomain = data.azurerm_key_vault_secret.jira_compliance["account-mapping-name"].value
}

data "pagerduty_jira_cloud_account_mapping" "cost" {
  subdomain = data.azurerm_key_vault_secret.jira_cost["account-mapping-name"].value
}

data "pagerduty_jira_cloud_account_mapping" "security" {
  subdomain = data.azurerm_key_vault_secret.jira_security["account-mapping-name"].value
}

data "pagerduty_priority" "p1" {
  name = "P1"
}

data "pagerduty_priority" "p2" {
  name = "P2"
}

data "pagerduty_priority" "p3" {
  name = "P3"
}

data "pagerduty_priority" "p4" {
  name = "P4"
}

data "pagerduty_priority" "p5" {
  name = "P5"
}

data "pagerduty_user" "account_user" {
  email = data.azurerm_key_vault_secret.jira_account["sync-notes-user"].value
}

data "pagerduty_user" "compliance_user" {
  email = data.azurerm_key_vault_secret.jira_compliance["sync-notes-user"].value
}

data "pagerduty_user" "cost_user" {
  email = data.azurerm_key_vault_secret.jira_cost["sync-notes-user"].value
}

data "pagerduty_user" "security_user" {
  email = data.azurerm_key_vault_secret.jira_security["sync-notes-user"].value
}
