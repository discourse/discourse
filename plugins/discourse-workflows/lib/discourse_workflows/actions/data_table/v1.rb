# frozen_string_literal: true

module DiscourseWorkflows
  module Actions
    module DataTable
      class V1 < Actions::Base
        OPERATIONS = %w[insert get update delete upsert].freeze

        def self.identifier
          "action:data_table"
        end

        def self.configuration_schema
          {
            operation: {
              type: :options,
              required: true,
              options: OPERATIONS,
              default: "get",
            },
            data_table_id: {
              type: :string,
              required: true,
            },
            fields: {
              type: :collection,
              required: false,
              visible_if: {
                operation: %w[insert update upsert],
              },
              ui: {
                control: :data_table_fields,
              },
              item_schema: {
                column: {
                  type: :string,
                  required: true,
                },
                value: {
                  type: :string,
                  required: true,
                },
              },
            },
            filter: {
              type: :string,
              required: false,
              visible_if: {
                operation: %w[get update delete upsert],
              },
              ui: {
                control: :code,
                expression: false,
                height: 180,
                lang: :json,
              },
            },
            limit: {
              type: :integer,
              required: false,
              visible_if: {
                operation: "get",
              },
            },
            sort_by: {
              type: :string,
              required: false,
              visible_if: {
                operation: "get",
              },
            },
            sort_direction: {
              type: :options,
              required: false,
              options: %w[asc desc],
              default: "asc",
              visible_if: {
                operation: "get",
              },
            },
          }
        end

        def self.output_schema
          {}
        end

        def execute_single(context, item:, config:)
          operation = config["operation"] || "insert"
          @data_table = DiscourseWorkflows::DataTable.find(config["data_table_id"].to_i)
          @repository = DiscourseWorkflows::DataTableRowsRepository.new(@data_table)

          case operation
          when "insert"
            execute_insert(config)
          when "get"
            execute_get(config)
          when "update"
            execute_update(config)
          when "delete"
            execute_delete(config)
          when "upsert"
            execute_upsert(config)
          else
            raise ArgumentError, "Unknown operation: #{operation}"
          end
        end

        private

        def execute_insert(config)
          data = build_row_data(config["fields"] || [])
          @repository.insert(data)
        end

        def execute_get(config)
          result =
            @repository.get_many_and_count(
              filter: parse_filter(config["filter"]),
              limit: config["limit"]&.to_i,
              sort_by: config["sort_by"],
              sort_direction: config["sort_direction"],
            )

          { "rows" => result[:rows], "count" => result[:count] }
        end

        def execute_update(config)
          rows =
            @repository.update_many(
              filter: parse_filter(config["filter"]),
              data: build_row_data(config["fields"] || []),
            )
          { "updated_count" => rows.length }
        end

        def execute_delete(config)
          count = @repository.delete_many(filter: parse_filter(config["filter"]))
          { "deleted_count" => count }
        end

        def execute_upsert(config)
          data = build_row_data(config["fields"] || [])
          filter = parse_filter(config["filter"])
          result = @repository.upsert(filter: filter, data: data)

          if result[:operation] == "update"
            { "operation" => "update", "count" => result[:rows].length }
          else
            { "operation" => "insert" }.merge(result[:row])
          end
        end

        def build_row_data(fields)
          column_map =
            @data_table.columns.index_by do |column|
              DiscourseWorkflows::DataTable.column_name(column)
            end

          fields.each_with_object({}) do |field, result|
            col_name = field["column"] || field[:column]
            col_def = column_map[col_name]
            raise DataTableValidationError, "Unknown column name '#{col_name}'" if col_def.blank?

            result[col_name] = DiscourseWorkflows::DataTableRow.normalize_value(
              field["value"] || field[:value],
              DiscourseWorkflows::DataTable.column_type(col_def),
            )
          end
        end

        def parse_filter(filter)
          return filter if filter.blank? || filter.is_a?(Hash)

          JSON.parse(filter)
        rescue JSON::ParserError => error
          raise DataTableValidationError, "Invalid filter JSON: #{error.message}"
        end
      end
    end
  end
end
