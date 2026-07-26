# Shared mock defaults for the pagerduty provider under `terraform test`.
# Referenced from every *.tftest.hcl via `mock_provider "pagerduty" { source =
# "./tests/setup-pagerduty" }`.
#
# Only the `type` attributes need pinning: the service-dependency blocks feed
# them back into PagerDuty, which validates them against a fixed enum, so the
# provider's random mock strings would be rejected. Everything else (ids,
# integration keys, ...) can use the auto-generated mock values.
mock_data "pagerduty_business_service" {
  defaults = {
    type = "business_service"
  }
}

mock_resource "pagerduty_business_service" {
  defaults = {
    type = "business_service"
  }
}

mock_resource "pagerduty_service" {
  defaults = {
    type = "service"
  }
}
