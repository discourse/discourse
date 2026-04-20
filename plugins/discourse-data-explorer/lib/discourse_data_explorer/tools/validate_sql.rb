# frozen_string_literal: true

module DiscourseDataExplorer
  module Tools
    class ValidateSql < DiscourseAi::Agents::Tools::Tool
      def self.signature
        {
          name: name,
          description:
            "Validates a SQL query for use in Data Explorer. Checks for prohibited syntax and verifies the query is valid PostgreSQL.",
          parameters: [
            {
              name: "sql",
              description: "the SQL query to validate (without semicolons)",
              type: "string",
              required: true,
            },
          ],
        }
      end

      def self.custom?
        true
      end

      def self.name
        "validate_sql"
      end

      def invoke
        sql = parameters[:sql].to_s.strip

        return error_response("SQL query is empty") if sql.blank?

        query = DiscourseDataExplorer::Query.new(name: "AI tool validation", sql: sql)
        result = DiscourseDataExplorer::DataExplorer.run_query(query, {}, limit: 0)

        return error_response(result[:error].message) if result[:error]

        { status: "valid" }
      end

      protected

      def description_args
        { sql: parameters[:sql].to_s.truncate(100) }
      end
    end
  end
end
