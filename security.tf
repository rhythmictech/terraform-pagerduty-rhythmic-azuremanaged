data "pagerduty_escalation_policy" "security" {
  name = "Security Notifications Policy"
}

resource "pagerduty_service" "security" {
  name                    = "${var.org_name} Security Notifications (${var.cloud_name} - ${var.customer_name})"
  acknowledgement_timeout = 43200
  alert_creation          = "create_alerts_and_incidents"
  auto_resolve_timeout    = "null"
  escalation_policy       = data.pagerduty_escalation_policy.security.id

  incident_urgency_rule {
    type = "use_support_hours"

    during_support_hours {
      type    = "constant"
      urgency = "high"
    }

    outside_support_hours {
      type    = "constant"
      urgency = "low"
    }
  }

  support_hours {
    type         = "fixed_time_per_day"
    time_zone    = "America/New_York"
    start_time   = "07:00:00"
    end_time     = "20:00:00"
    days_of_week = [1, 2, 3, 4, 5]
  }

  scheduled_actions {
    type       = "urgency_change"
    to_urgency = "high"

    at {
      type = "named_time"
      name = "support_hours_start"
    }
  }
}

resource "pagerduty_service_dependency" "security" {
  dependency {
    dependent_service {
      id   = pagerduty_business_service.azure.id
      type = "business_service"
    }
    supporting_service {
      id   = pagerduty_service.security.id
      type = pagerduty_service.security.type
    }
  }
}

resource "pagerduty_slack_connection" "security" {
  count = var.slack_security_team_channel != null ? 1 : 0

  channel_id        = var.slack_security_team_channel
  notification_type = "responder"
  source_id         = pagerduty_service.security.id
  source_type       = "service_reference"
  workspace_id      = var.slack_workspace_id

  config {
    events = [
      "incident.triggered",
      "incident.acknowledged",
      "incident.escalated",
      "incident.resolved",
      "incident.reassigned",
      "incident.unacknowledged",
      "incident.delegated",
      "incident.priority_updated",
      "incident.responder.added",
      "incident.responder.replied",
      "incident.status_update_published",
      "incident.reopened"
    ]
    priorities = ["*"]
  }
}

resource "pagerduty_service_integration" "security" {
  name    = data.pagerduty_vendor.datadog.name
  service = pagerduty_service.security.id
  vendor  = data.pagerduty_vendor.datadog.id
}

resource "pagerduty_jira_cloud_account_mapping_rule" "security" {
  name            = "jira-${pagerduty_service.security.id}"
  account_mapping = data.pagerduty_jira_cloud_account_mapping.security.id

  config {
    service = pagerduty_service.security.id
    jira {
      create_issue_on_incident_trigger = data.azurerm_key_vault_secret.jira_security["create-issue-on-incident-trigger"].value
      sync_notes_user                  = data.pagerduty_user.security_user.id

      custom_fields {
        source_incident_field   = "incident_description"
        target_issue_field      = "description"
        target_issue_field_name = "Description"
        type                    = "attribute"
      }

      custom_fields {
        source_incident_field   = "incident_title"
        target_issue_field      = "summary"
        target_issue_field_name = "Summary"
        type                    = "attribute"
      }

      custom_fields {
        target_issue_field      = "customfield_10002"
        target_issue_field_name = "Organization"
        type                    = "const"
        value                   = var.jira_organization_id
      }

      dynamic "custom_fields" {
        for_each = coalesce(jsondecode(nonsensitive(data.azurerm_key_vault_secret.jira_security["custom-jira-fields"].value)), [])

        content {
          target_issue_field      = custom_fields.value.target_issue_field
          target_issue_field_name = custom_fields.value.target_issue_field_name
          type                    = "jira_value"
          value                   = custom_fields.value.value
        }
      }

      dynamic "custom_fields" {
        for_each = coalesce(jsondecode(nonsensitive(data.azurerm_key_vault_secret.jira_security["custom-fixed-fields"].value)), [])

        content {
          target_issue_field      = custom_fields.value.target_issue_field
          target_issue_field_name = custom_fields.value.target_issue_field_name
          type                    = "const"
          value                   = custom_fields.value.value
        }
      }

      issue_type {
        id   = nonsensitive(split(":", data.azurerm_key_vault_secret.jira_security["issue-type"].value)[0])
        name = nonsensitive(split(":", data.azurerm_key_vault_secret.jira_security["issue-type"].value)[1])
      }

      priorities {
        jira_id      = "10000"
        pagerduty_id = data.pagerduty_priority.p1.id
      }

      priorities {
        jira_id      = "2"
        pagerduty_id = data.pagerduty_priority.p2.id
      }

      priorities {
        jira_id      = "3"
        pagerduty_id = data.pagerduty_priority.p3.id
      }


      priorities {
        jira_id      = "4"
        pagerduty_id = data.pagerduty_priority.p4.id
      }

      priorities {
        jira_id      = "4"
        pagerduty_id = data.pagerduty_priority.p5.id
      }

      project {
        id   = nonsensitive(split(":", data.azurerm_key_vault_secret.jira_security["project"].value)[0])
        key  = nonsensitive(split(":", data.azurerm_key_vault_secret.jira_security["project"].value)[1])
        name = data.azurerm_key_vault_secret.jira_security["project-name"].value
      }

      status_mapping {

        acknowledged {
          id   = nonsensitive(split(":", data.azurerm_key_vault_secret.jira_security["issue-status-acknowledged"].value)[0])
          name = nonsensitive(split(":", data.azurerm_key_vault_secret.jira_security["issue-status-acknowledged"].value)[1])
        }
        resolved {
          id   = nonsensitive(split(":", data.azurerm_key_vault_secret.jira_security["issue-status-resolved"].value)[0])
          name = nonsensitive(split(":", data.azurerm_key_vault_secret.jira_security["issue-status-resolved"].value)[1])
        }
        triggered {
          id   = nonsensitive(split(":", data.azurerm_key_vault_secret.jira_security["issue-status-open"].value)[0])
          name = nonsensitive(split(":", data.azurerm_key_vault_secret.jira_security["issue-status-open"].value)[1])
        }
      }
    }
  }
}
