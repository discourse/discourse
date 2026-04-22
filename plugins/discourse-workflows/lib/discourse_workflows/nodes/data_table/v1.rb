# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module DataTable
      class V1 < NodeType
        OPERATIONS = %w[insert get update delete upsert].freeze
        MAPPING_MODES = %w[manual auto].freeze

        def self.identifier
          "action:data_table"
        end

        def self.icon
          "table"
        end

        def self.color
          "violet"
        end

        def self.group
          "data"
        end

        def self.property_i18n_scope
          "data_table_node"
        end

        def self.operation_label_key(operation)
          "#{property_i18n_prefix}.#{property_i18n_scope}.operations.#{operation}"
        end

        def self.property_schema
          {
            operation: {
              type: :options,
              required: true,
              options: OPERATIONS,
              default: "insert",
            },
            data_table_id: {
              type: :integer,
              required: true,
              options_source: "data_tables",
              ui: {
                control: :combo_box,
              },
              control_options: {
                value_property: "id",
                name_property: "name",
                filterable: true,
                none: "discourse_workflows.data_table_node.data_table_id_placeholder",
                resets: %w[filter columns sort_column output_fields],
              },
            },
            mapping_mode: {
              type: :options,
              required: true,
              options: MAPPING_MODES,
              default: "manual",
              visible_if: {
                operation: "insert",
              },
              ui: {
                expression: false,
              },
            },
            columns_case_sensitive_hint: {
              type: :notice,
              visible_if: {
                operation: "insert",
                mapping_mode: "manual",
              },
            },
            columns: {
              type: :object,
              required: false,
              default: {
              },
              visible_if: {
                operation: %w[insert update upsert],
              },
              visible_unless: {
                mapping_mode: "auto",
              },
              ui: {
                control: :data_table_columns,
              },
            },
            filter_combinator: {
              type: :options,
              options: %w[and or],
              default: "and",
              required: false,
              visible_if: {
                operation: %w[get update delete upsert],
              },
              ui: {
                expression: false,
              },
            },
            filter: {
              type: :array,
              required: false,
              visible_if: {
                operation: %w[get update delete upsert],
              },
              ui: {
                control: :data_table_condition_builder,
              },
            },
            limit: {
              type: :integer,
              required: false,
              visible_if: {
                operation: "get",
              },
            },
            sort_column: {
              type: :string,
              required: false,
              visible_if: {
                operation: "get",
              },
              ui: {
                control: :data_table_column_select,
                format: :full,
              },
              control_options: {
                none: "discourse_workflows.data_table_node.sort_column_placeholder",
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
            output_fields: {
              type: :array,
              required: false,
              ui: {
                hidden: true,
              },
            },
          }
        end

        def self.metadata
          {
            data_tables:
              DiscourseWorkflows::DataTable
                .order(:name)
                .map do |dt|
                  {
                    id: dt.id,
                    name: dt.name,
                    columns:
                      dt.columns.map do |c|
                        col = { name: c["name"], type: c["type"] }
                        if DataTables::Storage::RESERVED_COLUMN_NAMES.include?(c["name"])
                          col[:reserved] = true
                        end
                        col
                      end,
                  }
                end,
          }
        end

        def self.output_schema
          {}
        end

        def execute(exec_ctx)
          @run_as_user = exec_ctx.run_as_user
          item = exec_ctx.input_items.first || { "json" => {} }
          config = exec_ctx.get_parameters(item)

          result = execute_with_config(config, item)
          [result]
        end

        private

        def execute_with_config(config, item)
          data_table = DiscourseWorkflows::DataTable.find(Integer(config.fetch("data_table_id")))
          facade = DiscourseWorkflows::DataTables::Facade.new(data_table)
          columns_resolver = ColumnsResolver.new(data_table)

          operation_name = config.fetch("operation") { "insert" }
          validate_storage_limit! unless operation_name == "get"

          config = auto_mapped_config(config, item, data_table) if auto_mapping?(
            config,
            operation_name,
          )

          Operations.for(operation_name).new(facade, columns_resolver).execute(config)
        end

        def auto_mapping?(config, operation_name)
          operation_name == "insert" && config["mapping_mode"] == "auto"
        end

        def auto_mapped_config(config, item, data_table)
          json = item["json"] || {}
          column_names = data_table.columns.map { |c| c["name"] }
          config.merge("columns" => json.slice(*column_names))
        end

        def validate_storage_limit!
          return if DiscourseWorkflows::DataTables::Facade.within_storage_limit?
          raise ArgumentError, "Data table storage limit exceeded"
        end
      end
    end
  end
end
