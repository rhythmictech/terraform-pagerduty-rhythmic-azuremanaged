########################################
# General Variables
########################################
variable "org_name" {
  description = "Organization or tenant name used in PagerDuty service and business-service display names (nickname or formal name)"
  type        = string
}

variable "cloud_name" {
  default     = "Azure"
  description = "Cloud provider name used in PagerDuty service and business-service display names (e.g., Azure, AWS, OCI, GCP)"
  type        = string
}

variable "customer_name" {
  description = "Customer Name"
  type        = string
}

variable "slack_compliance_team_channel" {
  default     = null
  description = "The Slack channel ID for the compliance team"
  type        = string
}

variable "slack_security_team_channel" {
  default     = null
  description = "The Slack channel ID for the security team"
  type        = string
}

variable "slack_customer_success_team_channel" {
  default     = null
  description = "The Slack channel ID for the customer success team"
  type        = string
}

variable "slack_workspace_id" {
  default     = null
  description = "The Slack workspace ID"
  type        = string
}

########################################
# Jira Integration
########################################
# The profile VALUES, keyed by profile name. The module reads no secret store:
# the caller supplies these from wherever the operator keeps them (for Rhythmic,
# the /config/jira/<profile>/<param> SSM parameters in its own ops account, the
# same source the AWS sibling module reads directly). Field shapes match those
# parameters one for one so values can be passed straight through: the five
# id:... fields are colon-joined and split inside the module, the two
# custom-field entries are JSON arrays of {target_issue_field,
# target_issue_field_name, value} objects ("[]" when there are none), and the
# create-issue trigger is "true" or "false". Pass plain (non-sensitive) values;
# the custom-field arrays drive for_each, which sensitive values cannot.
variable "jira_profiles" {
  description = "Jira integration profiles keyed by profile name; each concern's *_jira_integration_profile input selects one. Field shapes mirror the fleet's /config/jira/<profile>/<param> parameters (see README)."
  type = map(object({
    account_mapping_name             = string
    project                          = string # "id:key"
    project_name                     = string
    issue_type                       = string # "id:name"
    issue_status_open                = string # "id:name"
    issue_status_acknowledged        = string # "id:name"
    issue_status_resolved            = string # "id:name"
    sync_notes_user                  = string # PagerDuty user email
    create_issue_on_incident_trigger = string # "true" or "false"
    custom_jira_fields               = string # JSON array
    custom_fixed_fields              = string # JSON array
  }))

  validation {
    condition = alltrue([
      for profile in [
        var.account_jira_integration_profile,
        var.compliance_jira_integration_profile,
        var.cost_jira_integration_profile,
        var.security_jira_integration_profile,
      ] : contains(keys(var.jira_profiles), profile)
    ])
    error_message = "Every *_jira_integration_profile must name a key of jira_profiles."
  }
}

variable "account_jira_integration_profile" {
  default     = "NOC"
  description = "Key of the jira_profiles entry the account service files tickets under"
  type        = string
}

variable "cost_jira_integration_profile" {
  default     = "NOC"
  description = "Key of the jira_profiles entry the cost service files tickets under"
  type        = string
}

variable "compliance_jira_integration_profile" {
  default     = "NOC"
  description = "Key of the jira_profiles entry the compliance service files tickets under"
  type        = string
}

variable "security_jira_integration_profile" {
  default     = "NOC"
  description = "Key of the jira_profiles entry the security service files tickets under"
  type        = string
}

variable "jira_organization_id" {
  type        = string
  description = "Organization ID for Jira integration"
}

########################################
# Suppression Rules
########################################
variable "account_suppression_rules" {
  default     = []
  description = "Event suppression rules (uses PagerDuty event orchestration, merged with `account_default_suppression_rules`)"
  type = list(object({
    label     = string
    condition = string
  }))
}

variable "account_default_suppression_rules" {
  default = [
    {
      label     = "Service Health planned maintenance"
      condition = "event.custom_details.body matches part 'Planned Maintenance' or event.custom_details.body matches part 'incidentType: Maintenance'"
    },
    {
      label     = "Advisor informational recommendation"
      condition = "event.custom_details.body matches part 'Microsoft.Advisor/recommendations'"
    }
  ]
  description = "Default event suppression rules (override to an empty list to disable)"
  type = list(object({
    label     = string
    condition = string
  }))
}

variable "account_timebound_suppression_rules" {
  default     = []
  description = "Timebound event suppression rules (uses PagerDuty event orchestration)"
  type = list(object({
    label      = string
    condition  = string
    start_time = string
    end_time   = string
  }))
}

variable "compliance_suppression_rules" {
  default     = []
  description = "Event suppression rules (uses PagerDuty event orchestration, merged with `compliance_default_suppression_rules`)"
  type = list(object({
    label     = string
    condition = string
  }))
}

# TODO reserving for future use
variable "compliance_default_suppression_rules" {
  default     = []
  description = "Default event suppression rules (override to an empty list to disable)"
  type = list(object({
    label     = string
    condition = string
  }))
}

variable "compliance_timebound_suppression_rules" {
  default     = []
  description = "Timebound event suppression rules (uses PagerDuty event orchestration)"
  type = list(object({
    label      = string
    condition  = string
    start_time = string
    end_time   = string
  }))
}

variable "cost_suppression_rules" {
  default     = []
  description = "Event suppression rules (uses PagerDuty event orchestration, merged with `cost_default_suppression_rules`)"
  type = list(object({
    label     = string
    condition = string
  }))
}

# TODO reserving for future use
variable "cost_default_suppression_rules" {
  default     = []
  description = "Default event suppression rules (override to an empty list to disable)"
  type = list(object({
    label     = string
    condition = string
  }))
}

variable "cost_timebound_suppression_rules" {
  default     = []
  description = "Timebound event suppression rules (uses PagerDuty event orchestration)"
  type = list(object({
    label      = string
    condition  = string
    start_time = string # Format "2024-03-00 00:00:00 Etc/UTC"
    end_time   = string # Format "2024-03-00 00:00:00 Etc/UTC"
  }))
}

variable "security_suppression_rules" {
  default     = []
  description = "Event suppression rules (uses PagerDuty event orchestration, merged with `security_default_suppression_rules`)"
  type = list(object({
    label     = string
    condition = string
  }))
}

variable "security_default_suppression_rules" {
  default = [
    {
      label     = "Defender informational alert"
      condition = "event.custom_details.body matches part 'severity: Informational' or event.custom_details.body matches part 'Severity: Informational'"
    }
  ]
  description = "Default event suppression rules (override to an empty list to disable)"
  type = list(object({
    label     = string
    condition = string
  }))
}

variable "security_timebound_suppression_rules" {
  default     = []
  description = "Timebound event suppression rules (uses PagerDuty event orchestration)"
  type = list(object({
    label      = string
    condition  = string
    start_time = string # Format "2024-03-00 00:00:00 Etc/UTC"
    end_time   = string # Format "2024-03-00 00:00:00 Etc/UTC"
  }))
}
