resource "pagerduty_business_service" "azure" {
  name        = "${var.org_name} - ${var.cloud_name} Managed Services (${var.customer_name})"
  description = "${var.cloud_name} Managed Services - account health, compliance, cost and security monitoring"
  team        = data.pagerduty_team.customer_success.id
}

resource "pagerduty_service_dependency" "azure" {
  dependency {
    dependent_service {
      id   = data.pagerduty_business_service.customer.id
      type = data.pagerduty_business_service.customer.type
    }
    supporting_service {
      id   = pagerduty_business_service.azure.id
      type = pagerduty_business_service.azure.type
    }
  }
}
