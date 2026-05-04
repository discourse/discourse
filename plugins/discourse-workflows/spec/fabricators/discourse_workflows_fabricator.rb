# frozen_string_literal: true

Fabricator(:discourse_workflows_workflow, class_name: "DiscourseWorkflows::Workflow") do
  name { sequence(:name) { |n| "Workflow #{n}" } }
  created_by { Fabricate(:user) }
  after_create { |workflow| DiscourseWorkflows::WorkflowDependencyIndexer.call(workflow) }
end

Fabricator(:discourse_workflows_execution, class_name: "DiscourseWorkflows::Execution") do
  workflow { Fabricate(:discourse_workflows_workflow) }
  status :pending
  trigger_data { {} }
end

Fabricator(
  :discourse_workflows_completed_execution,
  from: :discourse_workflows_execution,
  class_name: "DiscourseWorkflows::Execution",
) do
  status :success
  started_at { 1.hour.ago }
  finished_at { Time.current }
end

Fabricator(
  :discourse_workflows_error_execution,
  from: :discourse_workflows_execution,
  class_name: "DiscourseWorkflows::Execution",
) do
  status :error
  started_at { 1.hour.ago }
  finished_at { Time.current }
end

Fabricator(
  :discourse_workflows_waiting_execution,
  from: :discourse_workflows_execution,
  class_name: "DiscourseWorkflows::Execution",
) do
  status :waiting
  waiting_until { 1.hour.from_now }
  resume_token { SecureRandom.hex(16) }
end

Fabricator(:discourse_workflows_execution_data, class_name: "DiscourseWorkflows::ExecutionData") do
  execution { Fabricate(:discourse_workflows_execution) }
  data { { "entries" => {}, "context" => {}, "node_contexts" => {} }.to_json }
  workflow_data { {} }
end

Fabricator(
  :discourse_workflows_execution_data_with_steps,
  from: :discourse_workflows_execution_data,
  class_name: "DiscourseWorkflows::ExecutionData",
) do
  transient :node_id, :node_name, :node_type, :step_status
  data do |attrs|
    node_id = attrs[:node_id] || "trigger-1"
    node_name = attrs[:node_name] || "Manual Trigger"
    node_type = attrs[:node_type] || "trigger:manual"
    step_status = attrs[:step_status] || "success"
    {
      "entries" => {
        node_name => [
          {
            "node_id" => node_id,
            "node_name" => node_name,
            "node_type" => node_type,
            "position" => 0,
            "status" => step_status,
            "input" => [],
            "output" => [],
            "started_at" => 1.hour.ago.iso8601,
            "finished_at" => Time.current.iso8601,
          },
        ],
      },
      "context" => {
      },
      "node_contexts" => {
      },
    }.to_json
  end
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
