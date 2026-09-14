# The examples/basic root config must produce a valid plan, guarding that the
# published example stays in sync with the module interface.

mock_provider "pagerduty" {
  source = "./tests/setup-pagerduty"
}

run "examples_basic_plans" {
  command = plan

  module {
    source = "./examples/basic"
  }
}
