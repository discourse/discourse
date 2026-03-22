# frozen_string_literal: true

Fabricator(:discourse_workflows_data_table, class_name: "DiscourseWorkflows::DataTable") do
  name { sequence(:name) { |n| "data_table_#{n}" } }
  columns { [{ "name" => "value", "type" => "string" }] }
end
