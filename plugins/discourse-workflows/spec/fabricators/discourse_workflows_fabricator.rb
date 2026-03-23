# frozen_string_literal: true

Fabricator(:discourse_workflows_workflow, class_name: "DiscourseWorkflows::Workflow") do
  name { sequence(:name) { |n| "Workflow #{n}" } }
  created_by { Fabricate(:user) }
end

Fabricator(:discourse_workflows_node, class_name: "DiscourseWorkflows::Node") do
  workflow { Fabricate(:discourse_workflows_workflow) }
  type "action:append_tags"
  name "Append Tags"
end

Fabricator(:discourse_workflows_connection, class_name: "DiscourseWorkflows::Connection") do
  workflow { Fabricate(:discourse_workflows_workflow) }
  source_node { |attrs| Fabricate(:discourse_workflows_node, workflow: attrs[:workflow]) }
  target_node { |attrs| Fabricate(:discourse_workflows_node, workflow: attrs[:workflow]) }
end

Fabricator(:discourse_workflows_execution, class_name: "DiscourseWorkflows::Execution") do
  workflow { Fabricate(:discourse_workflows_workflow) }
  status :pending
end

Fabricator(:discourse_workflows_variable, class_name: "DiscourseWorkflows::Variable") do
  key { sequence(:key) { |n| "variable_#{n}" } }
  value "test_value"
end
