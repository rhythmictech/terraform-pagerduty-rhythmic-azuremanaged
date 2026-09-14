# Slack wiring: with a workspace and all three channels set, each concern gets a
# Slack connection. Account and cost both route to the customer-success channel;
# compliance and security route to their own.

mock_provider "pagerduty" {
  source = "./tests/setup-pagerduty"
}

# One Jira profile is enough for every run: all four concerns default to "NOC".
# The values are shaped like the fleet's SSM parameters ("id:key", "id:name",
# JSON arrays), which is the contract the module documents.
variables {
  jira_profiles = {
    NOC = {
      account_mapping_name             = "example-jira"
      project                          = "10001:OPS"
      project_name                     = "Operations"
      issue_type                       = "10002:Task"
      issue_status_open                = "1:Open"
      issue_status_acknowledged        = "3:In Progress"
      issue_status_resolved            = "5:Done"
      sync_notes_user                  = "noc@example.com"
      create_issue_on_incident_trigger = "true"
      custom_jira_fields               = "[]"
      custom_fixed_fields              = "[]"
    }
  }
}

run "all_channels_wired" {
  command = plan

  variables {
    org_name             = "TestOrg"
    customer_name        = "TestCustomer"
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
    jira_organization_id = "test-org-id"
  }

  assert {
    condition     = length(pagerduty_slack_connection.account) == 0 && length(pagerduty_slack_connection.security) == 0
    error_message = "no channels means no Slack connections"
  }
}
