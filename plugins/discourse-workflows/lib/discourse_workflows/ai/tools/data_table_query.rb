# frozen_string_literal: true

module DiscourseWorkflows
  module Ai
    module Tools
      class DataTableQuery < DataTableBase
        def self.signature
          {
            name: name,
            description:
              "Reads rows from a workflow data table. Returns at most #{DiscourseWorkflows::Pagination::MAX_LIMIT} rows per call; use offset to page.",
            json_schema: {
              type: "object",
              additionalProperties: false,
              required: %w[table],
              properties: {
                table: TABLE_SCHEMA,
                filter: FILTER_SCHEMA,
                sort_by: {
                  type: "string",
                  description: "Column name to sort by",
                },
                sort_direction: {
                  type: "string",
                  enum: DiscourseWorkflows::DataTables::Facade::SORT_DIRECTIONS.keys,
                },
                limit: {
                  type: "integer",
                  description:
                    "Rows to return, default #{DiscourseWorkflows::Pagination::DEFAULT_LIMIT}, max #{DiscourseWorkflows::Pagination::MAX_LIMIT}",
                },
                offset: {
                  type: "integer",
                },
              },
            },
          }
        end

        def self.name
          "data_table_query"
        end

        def invoke
          with_data_table do |data_table|
            result =
              node_proxy(data_table).get_many_rows_and_count(
                filter: parameters[:filter],
                take:
                  DiscourseWorkflows::Pagination.normalize_limit(
                    Integer(parameters[:limit], exception: false),
                  ),
                skip: parameters[:offset],
                sort_by: [parameters[:sort_by], parameters[:sort_direction]],
              )

            {
              status: "success",
              table: data_table.name,
              count: result[:count],
              rows: json_safe(result[:data]),
            }
          end
        end
      end
    end
  end
end
