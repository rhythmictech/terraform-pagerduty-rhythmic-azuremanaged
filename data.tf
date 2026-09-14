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
