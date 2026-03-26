# frozen_string_literal: true

module DiscourseDataExplorer
  module Tools
    class RunSql < DiscourseAi::Agents::Tools::Tool
      MAX_ROWS = 20
      MAX_CELL_LENGTH = 200

      def self.signature
        {
          name: name,
          description:
            "Runs a SQL query in Data Explorer and returns the results. Use this to verify a query produces correct output.",
          parameters: [
            {
              name: "sql",
              description: "the SQL query to run (without semicolons)",
              type: "string",
              required: true,
            },
          ],
        }
      end

      def self.name
        "run_sql"
      end

      def invoke
        sql = parameters[:sql].to_s.strip

        return error_response("SQL query is empty") if sql.blank?

        return error_response("semicolons are not allowed in Data Explorer queries") if sql =~ /;/

        result = nil
        err = nil

        begin
          ActiveRecord::Base.connection.transaction do
            DB.exec("SET TRANSACTION READ ONLY")
            DB.exec("SET LOCAL statement_timeout = 10000")

            wrapped_sql = <<~SQL
              WITH query AS (
              #{sql}
              ) SELECT * FROM query
              LIMIT #{MAX_ROWS + 1}
            SQL

            result = ActiveRecord::Base.connection.raw_connection.async_exec(wrapped_sql)
            result.check

            raise ActiveRecord::Rollback
          end
        rescue ActiveRecord::Rollback
          # expected
        rescue => e
          err = e
        end

        return error_response(err.message) if err

        columns = result.fields
        rows = result.values
        total_rows = rows.length
        rows = rows.first(MAX_ROWS)

        # truncate long cell values
        rows =
          rows.map do |row|
            row.map do |cell|
              if cell.is_a?(String) && cell.length > MAX_CELL_LENGTH
                "#{cell[0...MAX_CELL_LENGTH]}..."
              else
                cell
              end
            end
          end

        { status: "success", columns: columns, rows: rows, row_count: total_rows }
      end

      protected

      def description_args
        { sql: parameters[:sql].to_s.truncate(100) }
      end
    end
  end
end
