# frozen_string_literal: true

Fabricator(:discourse_workflows_data_table, class_name: "DiscourseWorkflows::DataTable") do
  transient :columns

  name { sequence(:name) { |n| "data_table_#{n}" } }

  after_build do |data_table, transients|
    Array(
      transients[:columns].presence || [{ "name" => "value", "type" => "string" }],
    ).each_with_index do |column, index|
      data_table.columns.build(
        name: DiscourseWorkflows::DataTableColumn.definition_name(column),
        column_type: DiscourseWorkflows::DataTableColumn.definition_type(column),
        position: index,
      )
    end
  end

  after_create { |data_table| DiscourseWorkflows::DataTableStorage.create_table!(data_table) }
end

Fabricator(
  :discourse_workflows_data_table_column,
  class_name: "DiscourseWorkflows::DataTableColumn",
) do
  data_table { Fabricate(:discourse_workflows_data_table) }
  name { sequence(:name) { |n| "column_#{n}" } }
  column_type "string"
  position { |attrs| attrs[:data_table].columns.size }
end
