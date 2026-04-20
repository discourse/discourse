# frozen_string_literal: true

module DiscourseDataExplorer
  module Workflows
    module SqlAction
      class V1 < DiscourseWorkflows::NodeType
        OPERATIONS = %w[queries raw].freeze

        def self.identifier
          "action:sql"
        end

        def self.icon
          "database"
        end

        def self.color_key
          "purple"
        end

        def self.available?
          SiteSetting.data_explorer_enabled
        end

        def self.unavailable_reason_key
          "discourse_workflows.node_unavailable.requires_data_explorer"
        end

        def self.property_schema
          {
            operation: {
              type: :options,
              required: true,
              options: OPERATIONS,
              default: "queries",
            },
            query_id: {
              type: :integer,
              required: true,
              visible_if: {
                operation: "queries",
              },
              ui: {
                control: :combo_box,
                options_source: "queries",
                value_property: "id",
                name_property: "name",
                filterable: true,
                resets: %w[query_params output_fields],
              },
            },
            query_params: {
              type: :object,
              required: false,
              visible_if: {
                operation: "queries",
              },
              ui: {
                control: :query_params,
              },
            },
            params: {
              type: :collection,
              required: false,
              visible_if: {
                operation: "raw",
              },
              item_schema: {
                name: {
                  type: :string,
                  required: true,
                },
                value: {
                  type: :string,
                  required: true,
                },
              },
            },
            query: {
              type: :string,
              required: true,
              visible_if: {
                operation: "raw",
              },
              ui: {
                control: :code,
                expression: false,
                height: 200,
                lang: :sql,
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
          persisted = DiscourseDataExplorer::Query.where(hidden: false).order(:name).to_a

          persisted_ids = persisted.map(&:id).to_set

          unpersisted_defaults =
            DiscourseDataExplorer::Queries.default.filter_map do |_, attributes|
              next if persisted_ids.include?(attributes[:id])
              q =
                DiscourseDataExplorer::Query.new(
                  id: attributes[:id],
                  name: attributes[:name],
                  sql: attributes[:sql],
                )
              q.user_id = Discourse::SYSTEM_USER_ID
              q
            end

          all_queries = (persisted + unpersisted_defaults).sort_by(&:name)

          {
            queries:
              all_queries.map do |q|
                { id: q.id, name: q.name, params: q.params.reject(&:internal?).map(&:to_hash) }
              end,
          }
        end

        def execute(exec_ctx)
          item = exec_ctx.input_items.first || { "json" => {} }
          config = exec_ctx.get_parameters(item)
          operation = config.fetch("operation") { "queries" }

          if operation == "queries"
            execute_saved_query(config)
          else
            execute_raw_sql(config)
          end
        end

        private

        def execute_saved_query(config)
          query_id = config["query_id"]
          raise ArgumentError, "No query selected" if query_id.blank?

          query = DiscourseDataExplorer::Query.find(query_id)
          raw_params = config.fetch("query_params") { {} }

          result =
            DiscourseDataExplorer::DataExplorer.run_query(
              query,
              raw_params,
              { limit: SiteSetting.data_explorer_query_result_limit },
            )

          raise ArgumentError, result[:error].message if result[:error]

          rows_to_items(result[:pg_result])
        end

        def execute_raw_sql(config)
          sql = config["query"].to_s
          raise ArgumentError, "No SQL query provided" if sql.blank?

          req_params = {}
          Array(config["params"]).each do |param|
            req_params[param["name"].to_sym] = param["value"] if param["name"].present?
          end

          if req_params.present?
            sql =
              MiniSql::InlineParamEncoder.new(ActiveRecord::Base.connection.raw_connection).encode(
                sql,
                req_params,
              )
          end

          query = DiscourseDataExplorer::Query.new(name: "workflow", sql: sql)
          result =
            DiscourseDataExplorer::DataExplorer.run_query(
              query,
              {},
              { limit: SiteSetting.data_explorer_query_result_limit },
            )

          raise ArgumentError, result[:error].message if result[:error]

          rows_to_items(result[:pg_result])
        end

        def rows_to_items(pg_result)
          columns = pg_result.fields
          items =
            pg_result.values.map do |row|
              json = {}
              columns.each_with_index { |col, i| json[col] = row[i] }
              { "json" => json }
            end
          [items]
        end
      end
    end
  end
end
