# basic

Minimal invocation of `terraform-pagerduty-rhythmic-azuremanaged`: the four
notification services (account, compliance, cost, security), the umbrella
business service and its dependencies, the Datadog service integrations and the
Jira Cloud mapping rules, plus one custom account suppression rule to show the
input shape.

The escalation policies, the customer business service, the "Customer Success
Team", the Jira Cloud account mapping and the Key Vault secrets must already
exist in PagerDuty and Azure (see the module README for the prerequisites and
the Key Vault secret naming contract).

```bash
terraform init
terraform plan
```
