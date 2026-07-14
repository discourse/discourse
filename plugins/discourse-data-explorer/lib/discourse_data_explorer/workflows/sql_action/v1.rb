# frozen_string_literal: true

module DiscourseDataExplorer
  module Workflows
    module SqlAction
      class V1 < DiscourseWorkflows::NodeType
        OPERATIONS = %w[queries raw].freeze

        description(
          name: "action:sql",
          version: "1.0",
          defaults: {
            icon: "database",
            color: "purple",
          },
          available: -> { SiteSetting.data_explorer_enabled },
          unavailable_reason_key: "discourse_workflows.node_unavailable.requires_data_explorer",
          outputs: [
            { key: "main", label_key: "discourse_workflows.sql.output.results" },
            { key: "empty", label_key: "discourse_workflows.sql.output.no_results" },
          ],
          capabilities: {
            run_scope: "all_items",
          },
          properties: {
            operation: {
              type: :options,
              required: true,
              options: OPERATIONS,
              default: "queries",
            },
            query_id: {
              type: :integer,
              required: true,
              type_options: {
                load_options_method: "queries",
              },
              display_options: {
                show: {
                  operation: ["queries"],
                },
              },
              ui: {
                control: :combo_box,
                dynamic_value: :query_id,
              },
              control_options: {
                value_property: "id",
                name_property: "name",
                filterable: true,
                resets: %w[query_params],
              },
            },
            query_params: {
              type: :object,
              required: false,
              display_options: {
                show: {
                  operation: ["queries"],
                },
              },
              ui: {
                control: :query_params,
              },
            },
            params: {
              type: :fixed_collection,
              required: false,
              display_options: {
                show: {
                  operation: ["raw"],
                },
              },
              type_options: {
                multiple_values: true,
              },
              options: [
                {
                  name: "values",
                  values: {
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
              ],
            },
            query: {
              type: :string,
              required: true,
              display_options: {
                show: {
                  operation: ["raw"],
                },
              },
              no_data_expression: true,
              ui: {
                control: :code,
              },
              control_options: {
                height: 200,
                lang: :sql,
              },
            },
          },
        )

        def self.load_options_context(context)
          case context.method_name
          when "queries"
            queries.select { |query| context.matches_filter?(query[:name]) }
          end
        end

        def self.queries
          persisted = DiscourseDataExplorer::Query.where(hidden: false).order(:name).to_a

          persisted_ids = persisted.map(&:id).to_set

          unpersisted_defaults =
            DiscourseDataExplorer::Queries.default.filter_map do |_, attributes|
              next if persisted_ids.include?(attributes[:id])
              DiscourseDataExplorer::Query.new(
                id: attributes[:id],
                name: attributes[:name],
                sql: attributes[:sql],
              ) { |q| q.user_id = Discourse::SYSTEM_USER_ID }
            end

          (persisted + unpersisted_defaults)
            .sort_by(&:name)
            .map do |q|
              { id: q.id, name: q.name, params: q.params.reject(&:internal?).map(&:to_hash) }
            end
        end

        def execute(exec_ctx)
          config = {
            "operation" => exec_ctx.get_node_parameter("operation", 0, default: "queries"),
            "query_id" => exec_ctx.get_node_parameter("query_id", 0),
            "query_params" => exec_ctx.get_node_parameter("query_params", 0, default: {}),
            "query" => exec_ctx.get_node_parameter("query", 0),
          }
          operation = config.fetch("operation") { "queries" }

          if operation == "queries"
            execute_saved_query(config)
          else
            execute_raw_sql(config, exec_ctx)
          end
        end

        private

        def execute_saved_query(config)
          query_id = config["query_id"]
          if query_id.blank?
            raise_node_error!(
              I18n.t("discourse_data_explorer.discourse_workflows.sql_action.no_query_selected"),
            )
          end

          query = DiscourseDataExplorer::Query.find(query_id)
          raw_params = config.fetch("query_params") { {} }

          result =
            DiscourseDataExplorer::DataExplorer.run_query(
              query,
              raw_params,
              { limit: SiteSetting.data_explorer_query_result_limit },
            )

          raise_node_error!(result[:error].message) if result[:error]

          rows_to_items(result[:pg_result])
        end

        def execute_raw_sql(config, exec_ctx)
          sql = config["query"].to_s
          if sql.blank?
            raise_node_error!(
              I18n.t("discourse_data_explorer.discourse_workflows.sql_action.no_sql_provided"),
            )
          end

          req_params = {}
          exec_ctx
            .get_node_parameter("params.values", 0, default: [])
            .each do |param|
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

          raise_node_error!(result[:error].message) if result[:error]

          rows_to_items(result[:pg_result])
        end

        def rows_to_items(pg_result)
          columns = pg_result.fields
          rows =
            pg_result.values.map do |row|
              json = {}
              columns.each_with_index { |col, i| json[col] = row[i] }
              { "json" => json }
            end

          return [], [{ "json" => {} }] if rows.empty?

          [rows, []]
        end
      end
    end
  end
end
