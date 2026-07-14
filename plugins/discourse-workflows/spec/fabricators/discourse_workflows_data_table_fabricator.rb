# frozen_string_literal: true

Fabricator(:discourse_workflows_data_table, class_name: "DiscourseWorkflows::DataTable") do
  transient :columns

  name { sequence(:name) { |n| "data_table_#{n}" } }

  after_create do |data_table, transients|
    columns =
      Array(
        (
          if transients[:columns].nil?
            [{ "name" => "value", "type" => "string" }]
          else
            transients[:columns]
          end
        ),
      ).map do |c|
        c = c.respond_to?(:to_h) ? c.to_h.deep_stringify_keys : c
        { "name" => c["name"].to_s, "type" => c["type"].to_s }
      end

    DiscourseWorkflows::DataTables::Facade.create_table!(data_table, columns: columns)
  end
end
