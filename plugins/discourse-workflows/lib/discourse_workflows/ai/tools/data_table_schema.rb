# frozen_string_literal: true

module DiscourseWorkflows
  module Ai
    module Tools
      class DataTableSchema < DataTableBase
        def self.signature
          {
            name: name,
            description:
              "Lists the workflow data tables this agent can use, with their columns, column types and row counts. Call this before querying or writing to a data table.",
            parameters: [
              {
                name: "query",
                description: "Optional partial table name to narrow the list",
                type: "string",
              },
            ],
          }
        end

        def self.name
          "data_table_schema"
        end

        def invoke
          authorized do
            scope = allowed_data_tables.order(:name)
            query = parameters[:query].to_s.strip
            if query.present?
              scope =
                scope.where(
                  "name ILIKE ?",
                  "%#{DiscourseWorkflows::DataTable.sanitize_sql_like(query)}%",
                )
            end

            data_tables = scope.to_a
            stats = DiscourseWorkflows::DataTables::Facade.batch_stats(data_tables.map(&:id))

            {
              status: "success",
              data_tables:
                data_tables.map do |data_table|
                  {
                    id: data_table.id,
                    name: data_table.name,
                    columns:
                      data_table.user_columns.map do |column|
                        {
                          name: DiscourseWorkflows::DataTable.column_name(column),
                          type: DiscourseWorkflows::DataTable.column_type(column),
                        }
                      end,
                    row_count: stats.dig(data_table.id, :row_count).to_i,
                  }
                end,
            }
          end
        end
      end
    end
  end
end
