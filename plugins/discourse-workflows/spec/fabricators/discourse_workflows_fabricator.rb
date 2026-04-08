# frozen_string_literal: true

Fabricator(:discourse_workflows_workflow, class_name: "DiscourseWorkflows::Workflow") do
  name { sequence(:name) { |n| "Workflow #{n}" } }
  created_by { Fabricate(:user) }
  after_create { |workflow| DiscourseWorkflows::WorkflowDependencyIndexer.call(workflow) }
end

Fabricator(:discourse_workflows_execution, class_name: "DiscourseWorkflows::Execution") do
  workflow { Fabricate(:discourse_workflows_workflow) }
  status :pending
end

Fabricator(:discourse_workflows_execution_data, class_name: "DiscourseWorkflows::ExecutionData") do
  execution { Fabricate(:discourse_workflows_execution) }
  data { {}.to_json }
  workflow_data { {} }
end

Fabricator(:discourse_workflows_variable, class_name: "DiscourseWorkflows::Variable") do
  key { sequence(:key) { |n| "variable_#{n}" } }
  value "test_value"
end

Fabricator(:discourse_workflows_credential, class_name: "DiscourseWorkflows::Credential") do
  name { sequence(:name) { |n| "Credential #{n}" } }
  credential_type "basic_auth"
  data do
    DiscourseWorkflows::CredentialEncryptor.encrypt({ "user" => "admin", "password" => "secret" })
  end
end
