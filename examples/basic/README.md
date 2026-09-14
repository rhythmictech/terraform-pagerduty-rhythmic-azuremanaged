# basic

Minimal invocation of `terraform-pagerduty-rhythmic-azuremanaged`: the four
notification services (account, compliance, cost, security), the umbrella
business service and its dependencies, the Datadog service integrations and the
Jira Cloud mapping rules, plus one custom account suppression rule to show the
input shape.

The escalation policies, the customer business service, the "Customer Success
Team" and the Jira Cloud account mapping must already exist in PagerDuty (see
the module README for the prerequisites). The Jira integration profile values
are supplied inline through `var.jira_profiles`; a client repository reads them
from wherever the operator keeps them instead (the module README shows the AWS
SSM wiring).

```bash
terraform init
terraform plan
```
