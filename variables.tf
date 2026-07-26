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

variable "key_vault_id" {
  description = "Resource ID of the existing Key Vault holding the Jira integration profile secrets (see README for the secret naming contract)"
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
variable "account_jira_integration_profile" {
  default     = "NOC"
  description = "The Jira integration profile"
  type        = string
  validation {
    condition     = can(regex("^[0-9a-zA-Z-]+$", var.account_jira_integration_profile))
    error_message = "Jira integration profile names may contain only letters, numbers, and dashes (they form Key Vault secret names)."
  }
}

variable "cost_jira_integration_profile" {
  default     = "NOC"
  description = "The Jira integration profile"
  type        = string
  validation {
    condition     = can(regex("^[0-9a-zA-Z-]+$", var.cost_jira_integration_profile))
    error_message = "Jira integration profile names may contain only letters, numbers, and dashes (they form Key Vault secret names)."
  }
}

variable "compliance_jira_integration_profile" {
  default     = "NOC"
  description = "The Jira integration profile"
  type        = string
  validation {
    condition     = can(regex("^[0-9a-zA-Z-]+$", var.compliance_jira_integration_profile))
    error_message = "Jira integration profile names may contain only letters, numbers, and dashes (they form Key Vault secret names)."
  }
}

variable "security_jira_integration_profile" {
  default     = "NOC"
  description = "The Jira integration profile"
  type        = string
  validation {
    condition     = can(regex("^[0-9a-zA-Z-]+$", var.security_jira_integration_profile))
    error_message = "Jira integration profile names may contain only letters, numbers, and dashes (they form Key Vault secret names)."
  }
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
