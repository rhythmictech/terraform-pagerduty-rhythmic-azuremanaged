# Shared mock defaults for the azurerm provider under `terraform test`.
# Referenced from every *.tftest.hcl via `mock_provider "azurerm" { source =
# "./tests/setup" }`, so the plan-only suite runs with no live Azure tenant and
# no Key Vault.
#
# The only azurerm type this module touches is the Key Vault secret data source.
# A fixed "id:name" default makes the `split(":", ...)` id/name extractions
# (issue_type, project, status_mapping) deterministic. The two JSON-array
# secrets per profile (custom-jira-fields, custom-fixed-fields) are not valid
# JSON under this default, so each test overrides those instances with
# `override_data` (see the individual *.tftest.hcl files).
mock_data "azurerm_key_vault_secret" {
  defaults = {
    value = "10001:Task"
  }
}
