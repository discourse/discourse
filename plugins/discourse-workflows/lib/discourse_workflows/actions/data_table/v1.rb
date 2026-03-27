# frozen_string_literal: true

module DiscourseWorkflows
  module Actions
    module DataTable
      class V1 < Actions::Base
        OPERATIONS = %w[insert get update delete upsert].freeze

        def self.identifier
          "action:data_table"
        end

        def self.icon
          "table"
        end

        def self.color_key
          "violet"
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
              type: :integer,
              required: true,
              ui: {
                control: :combo_box,
                options_source: "data_tables",
                value_property: "id",
                name_property: "name",
                filterable: true,
                none: "discourse_workflows.data_table_node.data_table_id_placeholder",
              },
            },
            columns: {
              type: :object,
              required: false,
              visible_if: {
                operation: %w[insert update upsert],
              },
              ui: {
                control: :data_table_columns,
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
            sort_column_id: {
              type: :string,
              required: false,
              visible_if: {
                operation: "get",
              },
              ui: {
                control: :data_table_column_select,
                none: "discourse_workflows.data_table_node.sort_column_id_placeholder",
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

        def self.metadata
          {
            data_tables:
              DiscourseWorkflows::DataTable
                .order(:name)
                .pluck(:id, :name)
                .map { |id, name| { id:, name: } },
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
            validate_storage_limit!
            execute_insert(config).tap { reset_cached_size! }
          when "get"
            execute_get(config)
          when "update"
            validate_storage_limit!
            execute_update(config).tap { reset_cached_size! }
          when "delete"
            execute_delete(config).tap { reset_cached_size! }
          when "upsert"
            validate_storage_limit!
            execute_upsert(config).tap { reset_cached_size! }
          else
            raise ArgumentError, "Unknown operation: #{operation}"
          end
        end

        private

        def validate_storage_limit!
          DiscourseWorkflows::DataTableSizeValidator.validate_size!
        end

        def reset_cached_size!
          DiscourseWorkflows::DataTableSizeValidator.reset!
        end

        def execute_insert(config)
          data = build_row_data(config["columns"] || {})
          @repository.insert(data)
        end

        def execute_get(config)
          result =
            @repository.get_many_and_count(
              filter: resolve_filter(parse_filter(config["filter"])),
              limit: config["limit"]&.to_i,
              sort_by: resolve_sort_column_name(config["sort_column_id"]),
              sort_direction: config["sort_direction"],
            )

          { "rows" => result[:rows], "count" => result[:count] }
        end

        def execute_update(config)
          updated_count =
            @repository.update_many(
              filter: resolve_filter(parse_filter(config["filter"])),
              data: build_row_data(config["columns"] || {}),
            )
          { "updated_count" => updated_count }
        end

        def execute_delete(config)
          count = @repository.delete_many(filter: resolve_filter(parse_filter(config["filter"])))
          { "deleted_count" => count }
        end

        def execute_upsert(config)
          data = build_row_data(config["columns"] || {})
          filter = resolve_filter(parse_filter(config["filter"]))
          result = @repository.upsert(filter: filter, data: data)

          if result[:operation] == "update"
            { "operation" => "update", "count" => result[:updated_count] }
          else
            { "operation" => "insert" }.merge(result[:row])
          end
        end

        def build_row_data(fields)
          normalize_fields(fields).each_with_object({}) do |(column_id, value), result|
            column = @data_table.column_map_by_id[column_id.to_s]
            raise DataTableValidationError, "Unknown column id '#{column_id}'" if column.blank?

            result[column.name] = DiscourseWorkflows::DataTableRow.normalize_value(
              value,
              DiscourseWorkflows::DataTable.column_type(column),
            )
          end
        end

        def normalize_fields(fields)
          if fields.is_a?(Hash)
            fields.stringify_keys
          elsif fields.is_a?(Array)
            fields.each_with_object({}) do |field, hash|
              hash[field["columnId"] || field[:columnId]] = (
                if field.key?("value")
                  field["value"]
                else
                  field[:value]
                end
              )
            end
          else
            {}
          end
        end

        def parse_filter(filter)
          return filter if filter.blank? || filter.is_a?(Hash)

          JSON.parse(filter)
        rescue JSON::ParserError => error
          raise DataTableValidationError, "Invalid filter JSON: #{error.message}"
        end

        def resolve_filter(filter)
          return filter if filter.blank?

          filters = filter["filters"] || []

          {
            "type" => filter["type"] || "and",
            "filters" =>
              filters.map do |condition|
                column_id = condition["columnId"] || condition[:columnId]
                column = @data_table.column_map_by_id[column_id.to_s]

                raise DataTableValidationError, "Unknown column id '#{column_id}'" if column.blank?

                {
                  "columnName" => column.name,
                  "condition" => condition["condition"] || condition[:condition],
                  "value" => condition.key?("value") ? condition["value"] : condition[:value],
                }
              end,
          }
        end

        def resolve_sort_column_name(column_id)
          return if column_id.blank?

          column = @data_table.column_map_by_id[column_id.to_s]
          raise DataTableValidationError, "Unknown column id '#{column_id}'" if column.blank?

          column.name
        end
      end
    end
  end
end
