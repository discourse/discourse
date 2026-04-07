# frozen_string_literal: true

module DiscourseDataExplorer
  module Workflows
    class SqlAction < DiscourseWorkflows::NodeType
      def self.identifier
        "action:sql"
      end

      def self.icon
        "database"
      end

      def self.color_key
        "purple"
      end

      def self.configuration_schema
        {
          params: {
            type: :collection,
            required: false,
            description: "Parameters can be used as :my_param in the SQL query.",
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
            ui: {
              control: :code,
              expression: false,
              height: 200,
              lang: :sql,
            },
          },
        }
      end

      def execute(exec_ctx)
        config = exec_ctx.resolve_config(@configuration)
        sql = config["query"].to_s

        raise ArgumentError, "No SQL query provided" if sql.blank?

        req_params = {}
        Array(config["params"]).each do |param|
          req_params[param["name"]] = param["value"] if param["name"].present?
        end

        query = DiscourseDataExplorer::Query.new(name: "workflow", sql: sql)
        result =
          DiscourseDataExplorer::DataExplorer.run_query(
            query,
            req_params,
            { limit: SiteSetting.data_explorer_query_result_limit },
          )

        raise ArgumentError, result[:error].message if result[:error]

        pg_result = result[:pg_result]
        columns = pg_result.fields

        pg_result.values.map do |row|
          json = {}
          columns.each_with_index { |col, i| json[col] = row[i] }
          { "json" => json }
        end
      end
    end
  end
end
