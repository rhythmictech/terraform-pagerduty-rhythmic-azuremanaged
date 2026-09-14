# terraform-pagerduty-rhythmic-azuremanaged

Provisions the PagerDuty side of Rhythmic's Azure managed-monitoring stack: four
notification services (account, compliance, cost and security), an umbrella
business service, the Datadog service integrations that Datadog monitors alert
into, and the native Jira Cloud issue mapping for each service. It is the Azure
sibling of `rhythmictech/rhythmic-awsmanaged/pagerduty` and exposes the same
output contract, so client repositories consume it as a drop-in replacement.

## What it creates

- One PagerDuty **business service** (`<org> - <cloud> Managed Services
  (<customer>)`) that hangs off the customer's existing business service.
- Four **notification services**: account, compliance and cost run at constant
  low urgency; security runs on a support-hours urgency schedule
  (high 07:00-20:00 America/New_York on weekdays, low otherwise).
- A **service dependency** wiring each notification service under the business
  service, and the business service under the customer business service.
- A **Datadog service integration** on each notification service (the
  `datadog_integrations` output feeds
  `datadog_integration_pagerduty_service_object` on the Datadog side).
- A **Jira Cloud account mapping rule** on each service, including the priority
  map (P1-P5), status mapping and any custom fields.
- Optional **Slack connections** per concern (created only when the matching
  channel id is supplied).
- Optional **event orchestration** suppression rules per concern (default,
  custom and timebound), used to mute known-benign signals.

## Prerequisites

These objects must already exist; the module data-sources them by name and does
not create them:

- The four escalation policies, by exact name: `Account Notifications Policy`,
  `Compliance Notifications Policy`, `Cost Notifications Policy` and
  `Security Notifications Policy`. They are shared with the AWS-managed
  customers.
- The customer **business service**, named exactly `var.customer_name`.
- The **Customer Success Team** in PagerDuty.
- A **Jira Cloud account mapping** in PagerDuty for each profile's subdomain.

## Jira integration profiles

Each notification service files its tickets under a **Jira integration
profile**: the Jira project, issue type, status mapping, sync-notes user and
custom fields for one destination. The module takes the profile **values** as
the `jira_profiles` input, a map keyed by profile name, and the four
`<concern>_jira_integration_profile` inputs select which entry each concern
uses (all four default to `NOC`). The module reads no secret store itself:
where the values live is the caller's decision, and the operator's own store is
the right place for what is operator-internal routing configuration.

Each entry carries eleven fields. Their shapes mirror the `/config/jira/<profile>/<param>`
parameters the AWS sibling module reads from SSM, one for one, so values pass
straight through:

| Field | Meaning | Value shape |
|---|---|---|
| `account_mapping_name` | Jira Cloud account mapping subdomain | plain string |
| `project` | Jira project | `id:key` (for example `10001:OPS`) |
| `project_name` | Jira project display name | plain string |
| `issue_type` | Jira issue type | `id:name` (for example `10001:Task`) |
| `issue_status_open` | status applied when an incident triggers | `id:name` |
| `issue_status_acknowledged` | status applied when acknowledged | `id:name` |
| `issue_status_resolved` | status applied when resolved | `id:name` |
| `sync_notes_user` | PagerDuty user email used to sync notes | plain string |
| `create_issue_on_incident_trigger` | auto-create a Jira issue on trigger | `"true"` or `"false"` |
| `custom_jira_fields` | dynamic Jira-value custom fields | JSON array, as a string |
| `custom_fixed_fields` | constant custom fields | JSON array, as a string |

The five `id:...` fields are colon-joined and split inside the module. The two
JSON-array fields each hold a list of objects with `target_issue_field`,
`target_issue_field_name` and `value` keys (use `"[]"` when there are none).
Pass **plain, non-sensitive** values: the custom-field arrays drive `for_each`,
which Terraform refuses for sensitive values.

Reading the profiles from AWS SSM in the operator's account, the way Rhythmic's
AWS client repositories do, looks like this in the calling configuration:

```hcl
locals {
  jira_profile_names = ["cs-account", "cs-compliance", "cs-cost", "noc"]
  jira_parameters = [
    "account_mapping_name", "project", "project_name", "issue_type",
    "issue_status_open", "issue_status_acknowledged", "issue_status_resolved",
    "sync_notes_user", "create_issue_on_incident_trigger",
    "custom_jira_fields", "custom_fixed_fields",
  ]
}

data "aws_ssm_parameter" "jira" {
  for_each = { for p in setproduct(local.jira_profile_names, local.jira_parameters) : "${p[0]}/${p[1]}" => p }

  name = "/config/jira/${each.value[0]}/${each.value[1]}"
}

locals {
  # String parameters: insecure_value is the same text without the sensitive
  # mark, which the module needs for its for_each over the custom-field arrays.
  jira_profiles = {
    for profile in local.jira_profile_names : profile => {
      for param in local.jira_parameters : param => data.aws_ssm_parameter.jira["${profile}/${param}"].insecure_value
    }
  }
}
```

## Suppression defaults

Default suppression rules ship enabled and are spread across the concerns whose
services receive the matching events. Override any concern's
`<concern>_default_suppression_rules` to `[]` to disable it.

| Rule label | Concern | Condition |
|---|---|---|
| Service Health planned maintenance | account | `event.custom_details.body matches part 'Planned Maintenance' or event.custom_details.body matches part 'incidentType: Maintenance'` |
| Advisor informational recommendation | account | `event.custom_details.body matches part 'Microsoft.Advisor/recommendations'` |
| Defender informational alert | security | `event.custom_details.body matches part 'severity: Informational' or event.custom_details.body matches part 'Severity: Informational'` |

> The condition strings match against the forwarded event body. The exact field
> and text depend on the Datadog monitor message templates and the forwarded
> event shape, so review them against sample event payloads before relying on
> them, and adjust or clear the defaults as needed.

## Output contract

The `datadog_integrations` output is a map keyed by concern
(`account`, `compliance`, `cost`, `security`), each entry carrying the service
`name` and integration `key`. It matches the AWS sibling exactly and is designed
to drive the Datadog side of the wiring:

```hcl
resource "datadog_integration_pagerduty_service_object" "this" {
  for_each = module.azure_managed_services.datadog_integrations

  service_name = each.value.name
  service_key  = each.value.key
}
```

Per-concern `*_service_id`, `*_service_name`, `*_datadog_integration_key` and
`*_datadog_mention` outputs, plus a `pagerduty_services` list, are also exposed.

## Usage

```hcl
module "azure_managed_services" {
  source = "git::https://github.com/rhythmictech/terraform-pagerduty-rhythmic-azuremanaged.git?ref=v0.2.0"

  org_name             = "ExampleOrg"
  customer_name        = "ExampleCustomer"
  jira_organization_id = "00000000-0000-0000-0000-000000000000"

  jira_profiles                       = local.jira_profiles
  account_jira_integration_profile    = "cs-account"
  compliance_jira_integration_profile = "cs-compliance"
  cost_jira_integration_profile       = "cs-cost"
  security_jira_integration_profile   = "noc"
}
```

The module needs only the `pagerduty` provider. See `examples/basic` for a
complete, self-contained invocation.

## Differences from the AWS sibling

Compared with `rhythmictech/rhythmic-awsmanaged/pagerduty`:

- `org_name` replaces `awsorg_name`, and `cloud_name` defaults to `Azure`.
- Jira integration profile values arrive through the `jira_profiles` input
  instead of being read from SSM inside the module. The field shapes are the
  same, so a caller can feed the module from the same SSM parameters (see
  above) or from anywhere else.
- The default suppression rules are Azure-specific and spread by concern
  (account gets the Service Health and Advisor rules; security gets the Defender
  rule) rather than shipping only on the account service.
- No cloud provider is required at all; the module is `pagerduty`-only.

## Upgrading from v0.1.0

v0.1.0 read the eleven parameters per profile from an Azure Key Vault named by
`key_vault_id`, as secrets called `jira-<profile>-<param>`. v0.2.0 removes that
input, the `azurerm` provider requirement and the Key Vault naming contract.
Pass the same values through `jira_profiles` (underscore-delimited field names,
identical shapes) and drop the vault; no PagerDuty resource changes.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9 |
| <a name="requirement_pagerduty"></a> [pagerduty](#requirement\_pagerduty) | ~> 3.17 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_pagerduty"></a> [pagerduty](#provider\_pagerduty) | 3.36.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [pagerduty_business_service.azure](https://registry.terraform.io/providers/PagerDuty/pagerduty/latest/docs/resources/business_service) | resource |
| [pagerduty_event_orchestration_service.account_rules](https://registry.terraform.io/providers/PagerDuty/pagerduty/latest/docs/resources/event_orchestration_service) | resource |
| [pagerduty_event_orchestration_service.compliance_rules](https://registry.terraform.io/providers/PagerDuty/pagerduty/latest/docs/resources/event_orchestration_service) | resource |
| [pagerduty_event_orchestration_service.cost_rules](https://registry.terraform.io/providers/PagerDuty/pagerduty/latest/docs/resources/event_orchestration_service) | resource |
| [pagerduty_event_orchestration_service.security_rules](https://registry.terraform.io/providers/PagerDuty/pagerduty/latest/docs/resources/event_orchestration_service) | resource |
| [pagerduty_jira_cloud_account_mapping_rule.account](https://registry.terraform.io/providers/PagerDuty/pagerduty/latest/docs/resources/jira_cloud_account_mapping_rule) | resource |
| [pagerduty_jira_cloud_account_mapping_rule.compliance](https://registry.terraform.io/providers/PagerDuty/pagerduty/latest/docs/resources/jira_cloud_account_mapping_rule) | resource |
| [pagerduty_jira_cloud_account_mapping_rule.cost](https://registry.terraform.io/providers/PagerDuty/pagerduty/latest/docs/resources/jira_cloud_account_mapping_rule) | resource |
| [pagerduty_jira_cloud_account_mapping_rule.security](https://registry.terraform.io/providers/PagerDuty/pagerduty/latest/docs/resources/jira_cloud_account_mapping_rule) | resource |
| [pagerduty_service.account](https://registry.terraform.io/providers/PagerDuty/pagerduty/latest/docs/resources/service) | resource |
| [pagerduty_service.compliance](https://registry.terraform.io/providers/PagerDuty/pagerduty/latest/docs/resources/service) | resource |
| [pagerduty_service.cost](https://registry.terraform.io/providers/PagerDuty/pagerduty/latest/docs/resources/service) | resource |
| [pagerduty_service.security](https://registry.terraform.io/providers/PagerDuty/pagerduty/latest/docs/resources/service) | resource |
| [pagerduty_service_dependency.account](https://registry.terraform.io/providers/PagerDuty/pagerduty/latest/docs/resources/service_dependency) | resource |
| [pagerduty_service_dependency.azure](https://registry.terraform.io/providers/PagerDuty/pagerduty/latest/docs/resources/service_dependency) | resource |
| [pagerduty_service_dependency.compliance](https://registry.terraform.io/providers/PagerDuty/pagerduty/latest/docs/resources/service_dependency) | resource |
| [pagerduty_service_dependency.cost](https://registry.terraform.io/providers/PagerDuty/pagerduty/latest/docs/resources/service_dependency) | resource |
| [pagerduty_service_dependency.security](https://registry.terraform.io/providers/PagerDuty/pagerduty/latest/docs/resources/service_dependency) | resource |
| [pagerduty_service_integration.account](https://registry.terraform.io/providers/PagerDuty/pagerduty/latest/docs/resources/service_integration) | resource |
| [pagerduty_service_integration.compliance](https://registry.terraform.io/providers/PagerDuty/pagerduty/latest/docs/resources/service_integration) | resource |
| [pagerduty_service_integration.cost](https://registry.terraform.io/providers/PagerDuty/pagerduty/latest/docs/resources/service_integration) | resource |
| [pagerduty_service_integration.security](https://registry.terraform.io/providers/PagerDuty/pagerduty/latest/docs/resources/service_integration) | resource |
| [pagerduty_slack_connection.account](https://registry.terraform.io/providers/PagerDuty/pagerduty/latest/docs/resources/slack_connection) | resource |
| [pagerduty_slack_connection.compliance](https://registry.terraform.io/providers/PagerDuty/pagerduty/latest/docs/resources/slack_connection) | resource |
| [pagerduty_slack_connection.cost](https://registry.terraform.io/providers/PagerDuty/pagerduty/latest/docs/resources/slack_connection) | resource |
| [pagerduty_slack_connection.security](https://registry.terraform.io/providers/PagerDuty/pagerduty/latest/docs/resources/slack_connection) | resource |
| [pagerduty_business_service.customer](https://registry.terraform.io/providers/PagerDuty/pagerduty/latest/docs/data-sources/business_service) | data source |
| [pagerduty_escalation_policy.account](https://registry.terraform.io/providers/PagerDuty/pagerduty/latest/docs/data-sources/escalation_policy) | data source |
| [pagerduty_escalation_policy.compliance](https://registry.terraform.io/providers/PagerDuty/pagerduty/latest/docs/data-sources/escalation_policy) | data source |
| [pagerduty_escalation_policy.cost](https://registry.terraform.io/providers/PagerDuty/pagerduty/latest/docs/data-sources/escalation_policy) | data source |
| [pagerduty_escalation_policy.security](https://registry.terraform.io/providers/PagerDuty/pagerduty/latest/docs/data-sources/escalation_policy) | data source |
| [pagerduty_jira_cloud_account_mapping.account](https://registry.terraform.io/providers/PagerDuty/pagerduty/latest/docs/data-sources/jira_cloud_account_mapping) | data source |
| [pagerduty_jira_cloud_account_mapping.compliance](https://registry.terraform.io/providers/PagerDuty/pagerduty/latest/docs/data-sources/jira_cloud_account_mapping) | data source |
| [pagerduty_jira_cloud_account_mapping.cost](https://registry.terraform.io/providers/PagerDuty/pagerduty/latest/docs/data-sources/jira_cloud_account_mapping) | data source |
| [pagerduty_jira_cloud_account_mapping.security](https://registry.terraform.io/providers/PagerDuty/pagerduty/latest/docs/data-sources/jira_cloud_account_mapping) | data source |
| [pagerduty_priority.p1](https://registry.terraform.io/providers/PagerDuty/pagerduty/latest/docs/data-sources/priority) | data source |
| [pagerduty_priority.p2](https://registry.terraform.io/providers/PagerDuty/pagerduty/latest/docs/data-sources/priority) | data source |
| [pagerduty_priority.p3](https://registry.terraform.io/providers/PagerDuty/pagerduty/latest/docs/data-sources/priority) | data source |
| [pagerduty_priority.p4](https://registry.terraform.io/providers/PagerDuty/pagerduty/latest/docs/data-sources/priority) | data source |
| [pagerduty_priority.p5](https://registry.terraform.io/providers/PagerDuty/pagerduty/latest/docs/data-sources/priority) | data source |
| [pagerduty_team.customer_success](https://registry.terraform.io/providers/PagerDuty/pagerduty/latest/docs/data-sources/team) | data source |
| [pagerduty_user.account_user](https://registry.terraform.io/providers/PagerDuty/pagerduty/latest/docs/data-sources/user) | data source |
| [pagerduty_user.compliance_user](https://registry.terraform.io/providers/PagerDuty/pagerduty/latest/docs/data-sources/user) | data source |
| [pagerduty_user.cost_user](https://registry.terraform.io/providers/PagerDuty/pagerduty/latest/docs/data-sources/user) | data source |
| [pagerduty_user.security_user](https://registry.terraform.io/providers/PagerDuty/pagerduty/latest/docs/data-sources/user) | data source |
| [pagerduty_vendor.datadog](https://registry.terraform.io/providers/PagerDuty/pagerduty/latest/docs/data-sources/vendor) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_account_default_suppression_rules"></a> [account\_default\_suppression\_rules](#input\_account\_default\_suppression\_rules) | Default event suppression rules (override to an empty list to disable) | <pre>list(object({<br/>    label     = string<br/>    condition = string<br/>  }))</pre> | <pre>[<br/>  {<br/>    "condition": "event.custom_details.body matches part 'Planned Maintenance' or event.custom_details.body matches part 'incidentType: Maintenance'",<br/>    "label": "Service Health planned maintenance"<br/>  },<br/>  {<br/>    "condition": "event.custom_details.body matches part 'Microsoft.Advisor/recommendations'",<br/>    "label": "Advisor informational recommendation"<br/>  }<br/>]</pre> | no |
| <a name="input_account_jira_integration_profile"></a> [account\_jira\_integration\_profile](#input\_account\_jira\_integration\_profile) | Key of the jira\_profiles entry the account service files tickets under | `string` | `"NOC"` | no |
| <a name="input_account_suppression_rules"></a> [account\_suppression\_rules](#input\_account\_suppression\_rules) | Event suppression rules (uses PagerDuty event orchestration, merged with `account_default_suppression_rules`) | <pre>list(object({<br/>    label     = string<br/>    condition = string<br/>  }))</pre> | `[]` | no |
| <a name="input_account_timebound_suppression_rules"></a> [account\_timebound\_suppression\_rules](#input\_account\_timebound\_suppression\_rules) | Timebound event suppression rules (uses PagerDuty event orchestration) | <pre>list(object({<br/>    label      = string<br/>    condition  = string<br/>    start_time = string<br/>    end_time   = string<br/>  }))</pre> | `[]` | no |
| <a name="input_cloud_name"></a> [cloud\_name](#input\_cloud\_name) | Cloud provider name used in PagerDuty service and business-service display names (e.g., Azure, AWS, OCI, GCP) | `string` | `"Azure"` | no |
| <a name="input_compliance_default_suppression_rules"></a> [compliance\_default\_suppression\_rules](#input\_compliance\_default\_suppression\_rules) | Default event suppression rules (override to an empty list to disable) | <pre>list(object({<br/>    label     = string<br/>    condition = string<br/>  }))</pre> | `[]` | no |
| <a name="input_compliance_jira_integration_profile"></a> [compliance\_jira\_integration\_profile](#input\_compliance\_jira\_integration\_profile) | Key of the jira\_profiles entry the compliance service files tickets under | `string` | `"NOC"` | no |
| <a name="input_compliance_suppression_rules"></a> [compliance\_suppression\_rules](#input\_compliance\_suppression\_rules) | Event suppression rules (uses PagerDuty event orchestration, merged with `compliance_default_suppression_rules`) | <pre>list(object({<br/>    label     = string<br/>    condition = string<br/>  }))</pre> | `[]` | no |
| <a name="input_compliance_timebound_suppression_rules"></a> [compliance\_timebound\_suppression\_rules](#input\_compliance\_timebound\_suppression\_rules) | Timebound event suppression rules (uses PagerDuty event orchestration) | <pre>list(object({<br/>    label      = string<br/>    condition  = string<br/>    start_time = string<br/>    end_time   = string<br/>  }))</pre> | `[]` | no |
| <a name="input_cost_default_suppression_rules"></a> [cost\_default\_suppression\_rules](#input\_cost\_default\_suppression\_rules) | Default event suppression rules (override to an empty list to disable) | <pre>list(object({<br/>    label     = string<br/>    condition = string<br/>  }))</pre> | `[]` | no |
| <a name="input_cost_jira_integration_profile"></a> [cost\_jira\_integration\_profile](#input\_cost\_jira\_integration\_profile) | Key of the jira\_profiles entry the cost service files tickets under | `string` | `"NOC"` | no |
| <a name="input_cost_suppression_rules"></a> [cost\_suppression\_rules](#input\_cost\_suppression\_rules) | Event suppression rules (uses PagerDuty event orchestration, merged with `cost_default_suppression_rules`) | <pre>list(object({<br/>    label     = string<br/>    condition = string<br/>  }))</pre> | `[]` | no |
| <a name="input_cost_timebound_suppression_rules"></a> [cost\_timebound\_suppression\_rules](#input\_cost\_timebound\_suppression\_rules) | Timebound event suppression rules (uses PagerDuty event orchestration) | <pre>list(object({<br/>    label      = string<br/>    condition  = string<br/>    start_time = string # Format "2024-03-00 00:00:00 Etc/UTC"<br/>    end_time   = string # Format "2024-03-00 00:00:00 Etc/UTC"<br/>  }))</pre> | `[]` | no |
| <a name="input_customer_name"></a> [customer\_name](#input\_customer\_name) | Customer Name | `string` | n/a | yes |
| <a name="input_jira_organization_id"></a> [jira\_organization\_id](#input\_jira\_organization\_id) | Organization ID for Jira integration | `string` | n/a | yes |
| <a name="input_jira_profiles"></a> [jira\_profiles](#input\_jira\_profiles) | Jira integration profiles keyed by profile name; each concern's *\_jira\_integration\_profile input selects one. Field shapes mirror the fleet's /config/jira/<profile>/<param> parameters (see README). | <pre>map(object({<br/>    account_mapping_name             = string<br/>    project                          = string # "id:key"<br/>    project_name                     = string<br/>    issue_type                       = string # "id:name"<br/>    issue_status_open                = string # "id:name"<br/>    issue_status_acknowledged        = string # "id:name"<br/>    issue_status_resolved            = string # "id:name"<br/>    sync_notes_user                  = string # PagerDuty user email<br/>    create_issue_on_incident_trigger = string # "true" or "false"<br/>    custom_jira_fields               = string # JSON array<br/>    custom_fixed_fields              = string # JSON array<br/>  }))</pre> | n/a | yes |
| <a name="input_org_name"></a> [org\_name](#input\_org\_name) | Organization or tenant name used in PagerDuty service and business-service display names (nickname or formal name) | `string` | n/a | yes |
| <a name="input_security_default_suppression_rules"></a> [security\_default\_suppression\_rules](#input\_security\_default\_suppression\_rules) | Default event suppression rules (override to an empty list to disable) | <pre>list(object({<br/>    label     = string<br/>    condition = string<br/>  }))</pre> | <pre>[<br/>  {<br/>    "condition": "event.custom_details.body matches part 'severity: Informational' or event.custom_details.body matches part 'Severity: Informational'",<br/>    "label": "Defender informational alert"<br/>  }<br/>]</pre> | no |
| <a name="input_security_jira_integration_profile"></a> [security\_jira\_integration\_profile](#input\_security\_jira\_integration\_profile) | Key of the jira\_profiles entry the security service files tickets under | `string` | `"NOC"` | no |
| <a name="input_security_suppression_rules"></a> [security\_suppression\_rules](#input\_security\_suppression\_rules) | Event suppression rules (uses PagerDuty event orchestration, merged with `security_default_suppression_rules`) | <pre>list(object({<br/>    label     = string<br/>    condition = string<br/>  }))</pre> | `[]` | no |
| <a name="input_security_timebound_suppression_rules"></a> [security\_timebound\_suppression\_rules](#input\_security\_timebound\_suppression\_rules) | Timebound event suppression rules (uses PagerDuty event orchestration) | <pre>list(object({<br/>    label      = string<br/>    condition  = string<br/>    start_time = string # Format "2024-03-00 00:00:00 Etc/UTC"<br/>    end_time   = string # Format "2024-03-00 00:00:00 Etc/UTC"<br/>  }))</pre> | `[]` | no |
| <a name="input_slack_compliance_team_channel"></a> [slack\_compliance\_team\_channel](#input\_slack\_compliance\_team\_channel) | The Slack channel ID for the compliance team | `string` | `null` | no |
| <a name="input_slack_customer_success_team_channel"></a> [slack\_customer\_success\_team\_channel](#input\_slack\_customer\_success\_team\_channel) | The Slack channel ID for the customer success team | `string` | `null` | no |
| <a name="input_slack_security_team_channel"></a> [slack\_security\_team\_channel](#input\_slack\_security\_team\_channel) | The Slack channel ID for the security team | `string` | `null` | no |
| <a name="input_slack_workspace_id"></a> [slack\_workspace\_id](#input\_slack\_workspace\_id) | The Slack workspace ID | `string` | `null` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_account_datadog_integration_key"></a> [account\_datadog\_integration\_key](#output\_account\_datadog\_integration\_key) | PagerDuty Datadog Integration for account notifications |
| <a name="output_account_datadog_mention"></a> [account\_datadog\_mention](#output\_account\_datadog\_mention) | PagerDuty Service Mention with proper formatting |
| <a name="output_account_service_id"></a> [account\_service\_id](#output\_account\_service\_id) | PagerDuty service ID for account notifications |
| <a name="output_account_service_name"></a> [account\_service\_name](#output\_account\_service\_name) | PagerDuty service name for account notifications |
| <a name="output_compliance_datadog_integration_key"></a> [compliance\_datadog\_integration\_key](#output\_compliance\_datadog\_integration\_key) | PagerDuty Datadog Integration for compliance notifications |
| <a name="output_compliance_datadog_mention"></a> [compliance\_datadog\_mention](#output\_compliance\_datadog\_mention) | PagerDuty Service Mention with proper formatting |
| <a name="output_compliance_service_id"></a> [compliance\_service\_id](#output\_compliance\_service\_id) | PagerDuty service ID for compliance notifications |
| <a name="output_compliance_service_name"></a> [compliance\_service\_name](#output\_compliance\_service\_name) | PagerDuty service name for compliance notifications |
| <a name="output_cost_datadog_integration_key"></a> [cost\_datadog\_integration\_key](#output\_cost\_datadog\_integration\_key) | PagerDuty Datadog Integration for cost notifications |
| <a name="output_cost_datadog_mention"></a> [cost\_datadog\_mention](#output\_cost\_datadog\_mention) | PagerDuty Service Mention with proper formatting |
| <a name="output_cost_service_id"></a> [cost\_service\_id](#output\_cost\_service\_id) | PagerDuty service ID for cost notifications |
| <a name="output_cost_service_name"></a> [cost\_service\_name](#output\_cost\_service\_name) | PagerDuty service name for cost notifications |
| <a name="output_datadog_integrations"></a> [datadog\_integrations](#output\_datadog\_integrations) | All PagerDuty Datadog integrations |
| <a name="output_pagerduty_services"></a> [pagerduty\_services](#output\_pagerduty\_services) | All PagerDuty services |
| <a name="output_security_datadog_integration_key"></a> [security\_datadog\_integration\_key](#output\_security\_datadog\_integration\_key) | PagerDuty Datadog Integration for security notifications |
| <a name="output_security_datadog_mention"></a> [security\_datadog\_mention](#output\_security\_datadog\_mention) | PagerDuty Service Mention with proper formatting |
| <a name="output_security_service_id"></a> [security\_service\_id](#output\_security\_service\_id) | PagerDuty service ID for security notifications |
| <a name="output_security_service_name"></a> [security\_service\_name](#output\_security\_service\_name) | PagerDuty service name for security notifications |
<!-- END_TF_DOCS -->
