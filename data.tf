locals {
  # The Jira integration profile each concern files tickets under, resolved from
  # var.jira_profiles by the four *_jira_integration_profile selectors. The
  # module takes the profile VALUES as input and reads no secret store itself;
  # where they live (AWS SSM in the operator's own account, a tfvars file, a
  # vault) is the caller's decision. See README, "Jira integration profiles".
  jira = {
    account    = var.jira_profiles[var.account_jira_integration_profile]
    compliance = var.jira_profiles[var.compliance_jira_integration_profile]
    cost       = var.jira_profiles[var.cost_jira_integration_profile]
    security   = var.jira_profiles[var.security_jira_integration_profile]
  }

  # Every incident event PagerDuty stores on a Slack connection, in the order
  # PagerDuty returns them. PagerDuty EXPANDS the list server-side: a
  # connection created with twelve events read back as nineteen, so every later
  # plan proposed removing the other seven, and applying that would have
  # narrowed what the channel receives. The ORDER matters too: provider
  # releases before 3.24.0 model `config.events` as a list, so a list in any
  # other order plans a perpetual in-place update; from 3.24.0 it is a set and
  # order is ignored. Measured against live connections on 2026-09-16. If
  # PagerDuty adds an event, add it here; never let an apply remove one.
  slack_connection_events = [
    "incident.triggered",
    "incident.responder.replied",
    "incident.priority_updated",
    "incident.reassigned",
    "incident.responder.added",
    "incident.reopened",
    "incident.acknowledged",
    "incident.delegated",
    "incident.status_update_published",
    "incident.resolved",
    "incident.unacknowledged",
    "incident.escalated",
    "incident.conference_bridge.updated",
    "incident.service_updated",
    "incident.custom_field_values.updated",
    "incident.urgency_updated",
    "incident.title_updated",
    "incident.workflow.started",
    "incident.workflow.completed",
  ]
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
  subdomain = local.jira.account.account_mapping_name
}

data "pagerduty_jira_cloud_account_mapping" "compliance" {
  subdomain = local.jira.compliance.account_mapping_name
}

data "pagerduty_jira_cloud_account_mapping" "cost" {
  subdomain = local.jira.cost.account_mapping_name
}

data "pagerduty_jira_cloud_account_mapping" "security" {
  subdomain = local.jira.security.account_mapping_name
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
  email = local.jira.account.sync_notes_user
}

data "pagerduty_user" "compliance_user" {
  email = local.jira.compliance.sync_notes_user
}

data "pagerduty_user" "cost_user" {
  email = local.jira.cost.sync_notes_user
}

data "pagerduty_user" "security_user" {
  email = local.jira.security.sync_notes_user
}
