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

      def self.name
        "validate_sql"
      end

      def invoke
        sql = parameters[:sql].to_s.strip

        return error_response("SQL query is empty") if sql.blank?

        return error_response("semicolons are not allowed in Data Explorer queries") if sql =~ /;/

        # strip DE-style params (:param_name) and replace with NULL for EXPLAIN
        explain_sql = sql.gsub(/(?<=\s|,|\():[a-zA-Z_]\w*/, "NULL")

        begin
          ActiveRecord::Base.connection.transaction do
            DB.exec("SET TRANSACTION READ ONLY")
            DB.exec("SET LOCAL statement_timeout = 5000")
            DB.exec("EXPLAIN #{explain_sql}")
            raise ActiveRecord::Rollback
          end
        rescue => e
          return error_response(e.message)
        end

        { status: "valid" }
      end

      protected

      def description_args
        { sql: parameters[:sql].to_s.truncate(100) }
      end
    end
  end
end
