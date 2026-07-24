data "pagerduty_escalation_policy" "cost" {
  name = "Cost Notifications Policy"
}

resource "pagerduty_service" "cost" {
  name                    = "${var.org_name} Cost Notifications (${var.cloud_name} - ${var.customer_name})"
  acknowledgement_timeout = 43200
  alert_creation          = "create_alerts_and_incidents"
  auto_resolve_timeout    = "null"
  escalation_policy       = data.pagerduty_escalation_policy.cost.id

  incident_urgency_rule {
    type    = "constant"
    urgency = "low"
  }
}

resource "pagerduty_service_dependency" "cost" {
  dependency {
    dependent_service {
      id   = pagerduty_business_service.azure.id
      type = "business_service"
    }
    supporting_service {
      id   = pagerduty_service.cost.id
      type = pagerduty_service.cost.type
    }
  }
}

resource "pagerduty_slack_connection" "cost" {
  count = var.slack_customer_success_team_channel != null ? 1 : 0

  channel_id        = var.slack_customer_success_team_channel
  notification_type = "responder"
  source_id         = pagerduty_service.cost.id
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

resource "pagerduty_service_integration" "cost" {
  name    = data.pagerduty_vendor.datadog.name
  service = pagerduty_service.cost.id
  vendor  = data.pagerduty_vendor.datadog.id
}

resource "pagerduty_jira_cloud_account_mapping_rule" "cost" {
  name            = "jira-${pagerduty_service.cost.id}"
  account_mapping = data.pagerduty_jira_cloud_account_mapping.cost.id

  config {
    service = pagerduty_service.cost.id
    jira {
      create_issue_on_incident_trigger = data.azurerm_key_vault_secret.jira_cost["create-issue-on-incident-trigger"].value
      sync_notes_user                  = data.pagerduty_user.cost_user.id

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
        for_each = coalesce(jsondecode(nonsensitive(data.azurerm_key_vault_secret.jira_cost["custom-jira-fields"].value)), [])

        content {
          target_issue_field      = custom_fields.value.target_issue_field
          target_issue_field_name = custom_fields.value.target_issue_field_name
          type                    = "jira_value"
          value                   = custom_fields.value.value
        }
      }

      dynamic "custom_fields" {
        for_each = coalesce(jsondecode(nonsensitive(data.azurerm_key_vault_secret.jira_cost["custom-fixed-fields"].value)), [])

        content {
          target_issue_field      = custom_fields.value.target_issue_field
          target_issue_field_name = custom_fields.value.target_issue_field_name
          type                    = "const"
          value                   = custom_fields.value.value
        }
      }

      issue_type {
        id   = nonsensitive(split(":", data.azurerm_key_vault_secret.jira_cost["issue-type"].value)[0])
        name = nonsensitive(split(":", data.azurerm_key_vault_secret.jira_cost["issue-type"].value)[1])
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
        id   = nonsensitive(split(":", data.azurerm_key_vault_secret.jira_cost["project"].value)[0])
        key  = nonsensitive(split(":", data.azurerm_key_vault_secret.jira_cost["project"].value)[1])
        name = data.azurerm_key_vault_secret.jira_cost["project-name"].value
      }

      status_mapping {

        acknowledged {
          id   = nonsensitive(split(":", data.azurerm_key_vault_secret.jira_cost["issue-status-acknowledged"].value)[0])
          name = nonsensitive(split(":", data.azurerm_key_vault_secret.jira_cost["issue-status-acknowledged"].value)[1])
        }
        resolved {
          id   = nonsensitive(split(":", data.azurerm_key_vault_secret.jira_cost["issue-status-resolved"].value)[0])
          name = nonsensitive(split(":", data.azurerm_key_vault_secret.jira_cost["issue-status-resolved"].value)[1])
        }
        triggered {
          id   = nonsensitive(split(":", data.azurerm_key_vault_secret.jira_cost["issue-status-open"].value)[0])
          name = nonsensitive(split(":", data.azurerm_key_vault_secret.jira_cost["issue-status-open"].value)[1])
        }
      }

    }
  }
}
