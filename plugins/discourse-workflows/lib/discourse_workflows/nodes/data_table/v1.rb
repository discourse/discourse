# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module DataTable
      class V1 < NodeType
        OPERATIONS = %w[insert get update delete upsert].freeze

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
                resets: %w[filter columns sort_column output_fields],
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
                    columns: dt.columns.map { |c| { name: c["name"], type: c["type"] } },
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

          result = execute_with_config(config)
          [result]
        end

        private

        def execute_with_config(config)
          data_table = DiscourseWorkflows::DataTable.find(Integer(config.fetch("data_table_id")))
          facade = DiscourseWorkflows::DataTables::Facade.new(data_table)
          filter_resolver = FilterResolver.new(data_table)
          columns_resolver = ColumnsResolver.new(data_table)

          operation_name = config.fetch("operation") { "insert" }
          validate_storage_limit! unless operation_name == "get"

          result =
            Operations
              .for(operation_name)
              .new(facade, filter_resolver, columns_resolver)
              .execute(config)
          DiscourseWorkflows::DataTables::Facade.reset_storage_cache! unless operation_name == "get"
          result
        end

        def validate_storage_limit!
          return if DiscourseWorkflows::DataTables::Facade.within_storage_limit?
          raise ArgumentError, "Data table storage limit exceeded"
        end
      end
    end
  end
end
