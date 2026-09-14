# The Jira integration profiles the module files tickets under. All four
# concerns use the module's default selector, "NOC", so one entry is enough
# here. The field shapes are the module's contract: colon-joined "id:key" and
# "id:name" values, JSON-array strings for the custom-field lists, and "true" or
# "false" for the create-issue trigger.
variable "jira_profiles" {
  description = "Jira integration profiles keyed by name, passed through to the module."
  type = map(object({
    account_mapping_name             = string
    project                          = string
    project_name                     = string
    issue_type                       = string
    issue_status_open                = string
    issue_status_acknowledged        = string
    issue_status_resolved            = string
    sync_notes_user                  = string
    create_issue_on_incident_trigger = string
    custom_jira_fields               = string
    custom_fixed_fields              = string
  }))
  default = {
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
