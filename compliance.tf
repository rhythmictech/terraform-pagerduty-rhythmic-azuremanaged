data "pagerduty_escalation_policy" "compliance" {
  name = "Compliance Notifications Policy"
}

resource "pagerduty_service" "compliance" {
  name                    = "${var.org_name} Compliance Notifications (${var.cloud_name} - ${var.customer_name})"
  acknowledgement_timeout = 43200
  alert_creation          = "create_alerts_and_incidents"
  auto_resolve_timeout    = "null"
  escalation_policy       = data.pagerduty_escalation_policy.compliance.id

  incident_urgency_rule {
    type    = "constant"
    urgency = "low"
  }
}

resource "pagerduty_service_dependency" "compliance" {
  dependency {
    dependent_service {
      id   = pagerduty_business_service.azure.id
      type = "business_service"
    }
    supporting_service {
      id   = pagerduty_service.compliance.id
      type = pagerduty_service.compliance.type
    }
  }
}

resource "pagerduty_slack_connection" "compliance" {
  count = var.slack_compliance_team_channel != null ? 1 : 0

  channel_id        = var.slack_compliance_team_channel
  notification_type = "responder"
  source_id         = pagerduty_service.compliance.id
  source_type       = "service_reference"
  workspace_id      = var.slack_workspace_id

  config {
    events     = local.slack_connection_events
    priorities = ["*"]
  }
}

resource "pagerduty_service_integration" "compliance" {
  name    = data.pagerduty_vendor.datadog.name
  service = pagerduty_service.compliance.id
  vendor  = data.pagerduty_vendor.datadog.id
}

resource "pagerduty_jira_cloud_account_mapping_rule" "compliance" {
  name            = "jira-${pagerduty_service.compliance.id}"
  account_mapping = data.pagerduty_jira_cloud_account_mapping.compliance.id

  config {
    service = pagerduty_service.compliance.id
    jira {
      create_issue_on_incident_trigger = local.jira.compliance.create_issue_on_incident_trigger
      sync_notes_user                  = data.pagerduty_user.compliance_user.id

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
        for_each = coalesce(jsondecode(local.jira.compliance.custom_jira_fields), [])

        content {
          target_issue_field      = custom_fields.value.target_issue_field
          target_issue_field_name = custom_fields.value.target_issue_field_name
          type                    = "jira_value"
          value                   = custom_fields.value.value
        }
      }

      dynamic "custom_fields" {
        for_each = coalesce(jsondecode(local.jira.compliance.custom_fixed_fields), [])

        content {
          target_issue_field      = custom_fields.value.target_issue_field
          target_issue_field_name = custom_fields.value.target_issue_field_name
          type                    = "const"
          value                   = custom_fields.value.value
        }
      }

      issue_type {
        id   = split(":", local.jira.compliance.issue_type)[0]
        name = split(":", local.jira.compliance.issue_type)[1]
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
        id   = split(":", local.jira.compliance.project)[0]
        key  = split(":", local.jira.compliance.project)[1]
        name = local.jira.compliance.project_name
      }

      status_mapping {

        acknowledged {
          id   = split(":", local.jira.compliance.issue_status_acknowledged)[0]
          name = split(":", local.jira.compliance.issue_status_acknowledged)[1]
        }
        resolved {
          id   = split(":", local.jira.compliance.issue_status_resolved)[0]
          name = split(":", local.jira.compliance.issue_status_resolved)[1]
        }
        triggered {
          id   = split(":", local.jira.compliance.issue_status_open)[0]
          name = split(":", local.jira.compliance.issue_status_open)[1]
        }
      }

    }
  }
}
