# Profile selection: each *_jira_integration_profile must name a key of
# jira_profiles, and the selected profile's values are what reach the Jira
# wiring for that concern.

mock_provider "pagerduty" {
  source = "./tests/setup-pagerduty"
}

variables {
  jira_profiles = {
    cs = {
      account_mapping_name             = "example-jira"
      project                          = "10001:CS"
      project_name                     = "Customer Success"
      issue_type                       = "10002:Task"
      issue_status_open                = "1:Open"
      issue_status_acknowledged        = "3:In Progress"
      issue_status_resolved            = "5:Done"
      sync_notes_user                  = "cs@example.com"
      create_issue_on_incident_trigger = "true"
      custom_jira_fields               = "[]"
      custom_fixed_fields              = "[]"
    }
    noc = {
      account_mapping_name             = "example-jira"
      project                          = "10003:NOC"
      project_name                     = "Network Operations"
      issue_type                       = "10002:Task"
      issue_status_open                = "1:Open"
      issue_status_acknowledged        = "3:In Progress"
      issue_status_resolved            = "5:Done"
      sync_notes_user                  = "noc@example.com"
      create_issue_on_incident_trigger = "false"
      custom_jira_fields               = "[]"
      custom_fixed_fields              = "[]"
    }
  }
}

# A selector that names no profile fails the jira_profiles validation. The
# default selector is "NOC", which this map deliberately does not carry, so
# leaving the other three unset exercises the same failure.
run "unknown_profile_rejected" {
  command = plan

  variables {
    org_name             = "TestOrg"
    customer_name        = "TestCustomer"
    jira_organization_id = "test-org-id"

    account_jira_integration_profile    = "cs"
    compliance_jira_integration_profile = "cs"
    cost_jira_integration_profile       = "cs"
    security_jira_integration_profile   = "does-not-exist"
  }

  expect_failures = [
    var.jira_profiles,
  ]
}

# Concerns route to different profiles independently, and each one's values
# land on its own resources.
run "per_concern_profile_selection" {
  command = plan

  variables {
    org_name             = "TestOrg"
    customer_name        = "TestCustomer"
    jira_organization_id = "test-org-id"

    account_jira_integration_profile    = "cs"
    compliance_jira_integration_profile = "cs"
    cost_jira_integration_profile       = "cs"
    security_jira_integration_profile   = "noc"
  }

  assert {
    condition     = data.pagerduty_user.account_user.email == "cs@example.com" && data.pagerduty_user.security_user.email == "noc@example.com"
    error_message = "each concern's sync-notes user should come from its own selected profile"
  }

  # config, jira and project are nested attributes (objects) on this
  # framework-based resource, so they are reached with dot access, not [0].
  assert {
    condition     = pagerduty_jira_cloud_account_mapping_rule.account.config.jira.project.key == "CS" && pagerduty_jira_cloud_account_mapping_rule.security.config.jira.project.key == "NOC"
    error_message = "the project key should be the second half of each profile's id:key value"
  }

  assert {
    condition     = pagerduty_jira_cloud_account_mapping_rule.security.config.jira.project.id == "10003" && pagerduty_jira_cloud_account_mapping_rule.security.config.jira.project.name == "Network Operations"
    error_message = "the project id and display name should come from the selected profile"
  }

  assert {
    condition     = pagerduty_jira_cloud_account_mapping_rule.account.config.jira.create_issue_on_incident_trigger == true && pagerduty_jira_cloud_account_mapping_rule.security.config.jira.create_issue_on_incident_trigger == false
    error_message = "the create-issue trigger should follow the selected profile"
  }
}
