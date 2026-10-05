# frozen_string_literal: true

module DiscourseDataExplorer
  module McpTools
    READ_SCOPE = "mcp:data-explorer:read"

    module Support
      module_function

      def query!(id, guardian:, admin: false)
        guardian.ensure_is_admin! if admin

        query = Query.find(id)
        if query.hidden || (!admin && !guardian.user_can_access_query?(query))
          raise DiscourseMcp::ToolError, I18n.t("discourse_data_explorer.mcp.query_not_found")
        end

        query
      rescue ActiveRecord::RecordNotFound
        raise DiscourseMcp::ToolError, I18n.t("discourse_data_explorer.mcp.query_not_found")
      end

      def parameter_json(parameter)
        {
          identifier: parameter.identifier,
          type: parameter.type.to_s,
          default: parameter.default&.to_s,
          nullable: parameter.nullable,
        }
      end

      def limit(value)
        return SiteSetting.data_explorer_query_result_limit if value.nil?
        return QUERY_RESULT_MAX_LIMIT if value == "ALL"

        value
      end
    end

    class GetQuery
      REQUIRED_SCOPES = [READ_SCOPE].freeze
      PARAMETER_SCHEMA =
        DiscourseMcp::OutputSchema.object(
          identifier: DiscourseMcp::OutputSchema::STRING,
          type: DiscourseMcp::OutputSchema::STRING,
          default: DiscourseMcp::OutputSchema::STRING_OR_NULL,
          nullable: DiscourseMcp::OutputSchema::BOOLEAN,
        )
      OUTPUT_SCHEMA =
        DiscourseMcp::OutputSchema.object(
          id: DiscourseMcp::OutputSchema::INTEGER,
          name: DiscourseMcp::OutputSchema::STRING,
          description: DiscourseMcp::OutputSchema::STRING_OR_NULL,
          username: DiscourseMcp::OutputSchema::STRING_OR_NULL,
          group_ids: {
            type: "array",
            items: DiscourseMcp::OutputSchema::INTEGER,
          },
          last_run_at: DiscourseMcp::OutputSchema::STRING_OR_NULL,
          sql: DiscourseMcp::OutputSchema::STRING,
          param_info: {
            type: "array",
            items: PARAMETER_SCHEMA,
          },
        )

      def self.call(arguments:, request_context:)
        query =
          Support.query!(arguments.fetch("id"), guardian: request_context.guardian, admin: true)

        DiscourseMcp::ToolHelpers.text_and_structured(
          id: query.id,
          name: query.name,
          description: query.description,
          username: query.user&.username,
          group_ids: query.groups.map(&:id),
          last_run_at: query.last_run_at&.iso8601,
          sql: query.sql,
          param_info:
            query.params.uniq(&:identifier).map { |parameter| Support.parameter_json(parameter) },
        )
      end
    end

    class RunQuery
      REQUIRED_SCOPES = [READ_SCOPE].freeze
      OUTPUT_SCHEMA =
        DiscourseMcp::OutputSchema.object(
          optional: %w[explain relations],
          columns: DiscourseMcp::OutputSchema::STRING_ARRAY,
          rows: {
            type: "array",
            items: {
              type: "array",
              items: DiscourseMcp::OutputSchema::ANY,
            },
          },
          result_count: DiscourseMcp::OutputSchema::INTEGER,
          duration_ms: {
            type: "number",
          },
          explain: DiscourseMcp::OutputSchema::STRING,
          relations: DiscourseMcp::OutputSchema::OBJECT,
        )

      def self.call(arguments:, request_context:)
        query = Support.query!(arguments.fetch("id"), guardian: request_context.guardian)
        QueryRunRateLimiter.perform!(query_id: query.id)
        query.record_run!

        result =
          QueryRunner.run(
            query,
            arguments["params"],
            current_user: request_context.user,
            explain: arguments.fetch("explain", false),
            limit: Support.limit(arguments["limit"]),
          )

        if result[:error]
          raise DiscourseMcp::ToolError,
                I18n.t(
                  "discourse_data_explorer.mcp.query_failed",
                  message: QueryErrorFormatter.message(result[:error]),
                )
        end

        output = {
          columns: result[:columns],
          rows: result[:rows],
          result_count: result[:result_count],
          duration_ms: result[:duration],
        }
        output[:explain] = result[:explain] if result[:explain]
        output[:relations] = result[:relations] if result[:relations].present?

        DiscourseMcp::ToolHelpers.text_and_structured(output)
      end
    end
  end
end
