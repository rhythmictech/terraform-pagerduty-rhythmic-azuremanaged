# Default happy path: with only the required inputs, the module creates the four
# notification services, the umbrella business service and its dependencies, the
# four Datadog integrations and Jira mapping rules, no Slack connections, and the
# spread suppression defaults (account: 2 rules, security: 1 rule, compliance and
# cost: none).

mock_provider "pagerduty" {
  source = "./tests/setup-pagerduty"
}

mock_provider "azurerm" {
  source = "./tests/setup"
}

# The colon default ("10001:Task") in the azurerm mock feeds the split-based
# id/name extractions. Two secret shapes need pinning per profile: the boolean
# create-issue trigger, and the two JSON-array custom-field secrets.
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

run "defaults" {
  command = plan

  variables {
    org_name             = "TestOrg"
    customer_name        = "TestCustomer"
    key_vault_id         = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.KeyVault/vaults/test-vault"
    jira_organization_id = "test-org-id"
  }

  # Four notification services, surfaced through the pagerduty_services output.
  assert {
    condition     = length(output.pagerduty_services) == 4
    error_message = "the module should create exactly four PagerDuty services"
  }

  # The umbrella business service carries the org, cloud and customer tokens.
  assert {
    condition     = pagerduty_business_service.azure.name == "TestOrg - Azure Managed Services (TestCustomer)"
    error_message = "business service name should be '<org> - <cloud> Managed Services (<customer>)'"
  }

  # Service display names embed the org name, the cloud name (Azure) and the
  # customer name.
  assert {
    condition     = pagerduty_service.account.name == "TestOrg Account Notifications (Azure - TestCustomer)"
    error_message = "account service name should embed org, cloud and customer tokens"
  }

  assert {
    condition     = pagerduty_service.compliance.name == "TestOrg Compliance Notifications (Azure - TestCustomer)"
    error_message = "compliance service name should embed org, cloud and customer tokens"
  }

  assert {
    condition     = pagerduty_service.cost.name == "TestOrg Cost Notifications (Azure - TestCustomer)"
    error_message = "cost service name should embed org, cloud and customer tokens"
  }

  assert {
    condition     = pagerduty_service.security.name == "TestOrg Security Notifications (Azure - TestCustomer)"
    error_message = "security service name should embed org, cloud and customer tokens"
  }

  # account, compliance and cost are constant low-urgency.
  assert {
    condition     = pagerduty_service.account.incident_urgency_rule[0].type == "constant" && pagerduty_service.account.incident_urgency_rule[0].urgency == "low"
    error_message = "account service should be constant low urgency"
  }

  assert {
    condition     = pagerduty_service.cost.incident_urgency_rule[0].type == "constant" && pagerduty_service.cost.incident_urgency_rule[0].urgency == "low"
    error_message = "cost service should be constant low urgency"
  }

  # security keeps the support-hours urgency schedule.
  assert {
    condition     = pagerduty_service.security.incident_urgency_rule[0].type == "use_support_hours"
    error_message = "security service should use support-hours urgency"
  }

  assert {
    condition     = pagerduty_service.security.support_hours[0].time_zone == "America/New_York" && pagerduty_service.security.support_hours[0].start_time == "07:00:00" && pagerduty_service.security.support_hours[0].end_time == "20:00:00"
    error_message = "security support hours should be 07:00-20:00 America/New_York"
  }

  assert {
    condition     = length(pagerduty_service.security.support_hours[0].days_of_week) == 5
    error_message = "security support hours should cover five weekdays"
  }

  # The umbrella dependency and each concern dependency hang off a business
  # service (resource ids are only known after apply, so assert the fixed
  # dependent-service type instead).
  assert {
    condition     = pagerduty_service_dependency.azure.dependency[0].dependent_service[0].type == "business_service"
    error_message = "the umbrella dependency's dependent service should be a business service"
  }

  assert {
    condition     = pagerduty_service_dependency.account.dependency[0].dependent_service[0].type == "business_service"
    error_message = "the account dependency should hang off a business service"
  }

  assert {
    condition     = pagerduty_service_dependency.security.dependency[0].dependent_service[0].type == "business_service"
    error_message = "the security dependency should hang off a business service"
  }

  # Four Datadog service integrations, one per concern (the vendor id resolves
  # from the shared Datadog vendor data source).
  assert {
    condition     = pagerduty_service_integration.account.vendor == data.pagerduty_vendor.datadog.id
    error_message = "account integration should attach the Datadog vendor"
  }

  assert {
    condition     = pagerduty_service_integration.cost.vendor == data.pagerduty_vendor.datadog.id
    error_message = "cost integration should attach the Datadog vendor"
  }

  assert {
    condition     = pagerduty_service_integration.security.vendor == data.pagerduty_vendor.datadog.id
    error_message = "security integration should attach the Datadog vendor"
  }

  # Four Jira mapping rules, each wired to its concern's account mapping.
  assert {
    condition     = pagerduty_jira_cloud_account_mapping_rule.account.account_mapping == data.pagerduty_jira_cloud_account_mapping.account.id
    error_message = "the account mapping rule should use the account account-mapping"
  }

  assert {
    condition     = pagerduty_jira_cloud_account_mapping_rule.cost.account_mapping == data.pagerduty_jira_cloud_account_mapping.cost.id
    error_message = "the cost mapping rule should use the cost account-mapping"
  }

  # No Slack connections without channel ids.
  assert {
    condition     = length(pagerduty_slack_connection.account) == 0 && length(pagerduty_slack_connection.compliance) == 0 && length(pagerduty_slack_connection.cost) == 0 && length(pagerduty_slack_connection.security) == 0
    error_message = "no Slack connections should be created when channels are unset"
  }

  # Suppression defaults are spread by concern: account gets two rules, security
  # one, compliance and cost none.
  assert {
    condition     = length(pagerduty_event_orchestration_service.account_rules) == 1
    error_message = "account orchestration should be created (it has default rules)"
  }

  assert {
    condition     = length(pagerduty_event_orchestration_service.account_rules[0].set[0].rule) == 2
    error_message = "account orchestration should carry the two default rules"
  }

  assert {
    condition     = length(pagerduty_event_orchestration_service.security_rules) == 1
    error_message = "security orchestration should be created (it has one default rule)"
  }

  assert {
    condition     = length(pagerduty_event_orchestration_service.security_rules[0].set[0].rule) == 1
    error_message = "security orchestration should carry the single default rule"
  }

  assert {
    condition     = length(pagerduty_event_orchestration_service.compliance_rules) == 0
    error_message = "compliance orchestration should be absent by default"
  }

  assert {
    condition     = length(pagerduty_event_orchestration_service.cost_rules) == 0
    error_message = "cost orchestration should be absent by default"
  }

  # Key Vault secret names follow the jira-<profile>-<param> contract.
  assert {
    condition     = data.azurerm_key_vault_secret.jira_account["project"].name == "jira-NOC-project"
    error_message = "account project secret name should be jira-NOC-project"
  }

  assert {
    condition     = data.azurerm_key_vault_secret.jira_security["account-mapping-name"].name == "jira-NOC-account-mapping-name"
    error_message = "security mapping-name secret name should be jira-NOC-account-mapping-name"
  }
}
