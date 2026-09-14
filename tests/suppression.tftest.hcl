# Suppression behavior: disabling the defaults removes the orchestrations,
# custom rules pass through verbatim, timebound rules wrap their condition with a
# now-window, and defaults are concatenated ahead of custom rules.

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

# Overriding the defaults to empty lists disables every orchestration.
run "defaults_disabled" {
  command = plan

  variables {
    org_name             = "TestOrg"
    customer_name        = "TestCustomer"
    jira_organization_id = "test-org-id"

    account_default_suppression_rules  = []
    security_default_suppression_rules = []
  }

  assert {
    condition     = length(pagerduty_event_orchestration_service.account_rules) == 0
    error_message = "clearing account defaults should remove the account orchestration"
  }

  assert {
    condition     = length(pagerduty_event_orchestration_service.security_rules) == 0
    error_message = "clearing security defaults should remove the security orchestration"
  }

  assert {
    condition     = length(pagerduty_event_orchestration_service.compliance_rules) == 0
    error_message = "compliance orchestration stays absent"
  }

  assert {
    condition     = length(pagerduty_event_orchestration_service.cost_rules) == 0
    error_message = "cost orchestration stays absent"
  }
}

# A single custom rule on an otherwise-empty concern yields one orchestration
# with one rule and the condition passed through unchanged.
run "custom_rule_passthrough" {
  command = plan

  variables {
    org_name             = "TestOrg"
    customer_name        = "TestCustomer"
    jira_organization_id = "test-org-id"

    compliance_suppression_rules = [
      {
        label     = "custom compliance mute"
        condition = "event.custom_details.body matches part 'noise'"
      }
    ]
  }

  assert {
    condition     = length(pagerduty_event_orchestration_service.compliance_rules) == 1
    error_message = "a custom compliance rule should create the compliance orchestration"
  }

  assert {
    condition     = length(pagerduty_event_orchestration_service.compliance_rules[0].set[0].rule) == 1
    error_message = "the compliance orchestration should carry exactly the one custom rule"
  }

  assert {
    condition     = pagerduty_event_orchestration_service.compliance_rules[0].set[0].rule[0].label == "custom compliance mute"
    error_message = "the custom rule label should pass through"
  }

  assert {
    condition     = pagerduty_event_orchestration_service.compliance_rules[0].set[0].rule[0].condition[0].expression == "event.custom_details.body matches part 'noise'"
    error_message = "the custom rule condition should pass through verbatim"
  }
}

# Timebound rules wrap their condition with a now-window.
run "timebound_wrapping" {
  command = plan

  variables {
    org_name             = "TestOrg"
    customer_name        = "TestCustomer"
    jira_organization_id = "test-org-id"

    account_default_suppression_rules = []
    account_timebound_suppression_rules = [
      {
        label      = "holiday freeze"
        condition  = "event.custom_details.body matches part 'deploy'"
        start_time = "2024-12-24 00:00:00 Etc/UTC"
        end_time   = "2024-12-26 00:00:00 Etc/UTC"
      }
    ]
  }

  assert {
    condition     = length(pagerduty_event_orchestration_service.account_rules) == 1
    error_message = "a timebound rule alone should still create the orchestration"
  }

  assert {
    condition     = pagerduty_event_orchestration_service.account_rules[0].set[0].rule[0].condition[0].expression == "(event.custom_details.body matches part 'deploy') and (now > 2024-12-24 00:00:00 Etc/UTC and now < 2024-12-26 00:00:00 Etc/UTC)"
    error_message = "timebound conditions should be wrapped with a now-window"
  }
}

# Defaults are concatenated ahead of custom rules.
run "concat_order" {
  command = plan

  variables {
    org_name             = "TestOrg"
    customer_name        = "TestCustomer"
    jira_organization_id = "test-org-id"

    account_suppression_rules = [
      {
        label     = "extra account mute"
        condition = "event.custom_details.body matches part 'extra'"
      }
    ]
  }

  # two account defaults + one custom = three rules.
  assert {
    condition     = length(pagerduty_event_orchestration_service.account_rules[0].set[0].rule) == 3
    error_message = "account should concat two defaults with one custom rule"
  }

  # defaults come first.
  assert {
    condition     = pagerduty_event_orchestration_service.account_rules[0].set[0].rule[0].label == "Service Health planned maintenance"
    error_message = "the first default rule should lead the set"
  }

  assert {
    condition     = pagerduty_event_orchestration_service.account_rules[0].set[0].rule[2].label == "extra account mute"
    error_message = "the custom rule should follow the defaults"
  }
}
