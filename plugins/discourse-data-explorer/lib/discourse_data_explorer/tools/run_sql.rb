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

      def self.custom?
        true
      end

      def self.name
        "run_sql"
      end

      def invoke
        sql = parameters[:sql].to_s.strip
        return error_response("SQL query is empty") if sql.blank?

        query = DiscourseDataExplorer::Query.new(name: "AI tool query", sql: sql)
        result = DiscourseDataExplorer::DataExplorer.run_query(query, {}, limit: MAX_ROWS + 1)

        return error_response(result[:error].message) if result[:error]

        pg_result = result[:pg_result]
        columns = pg_result.fields
        rows = pg_result.values
        total_rows = rows.length
        rows = rows.first(MAX_ROWS)

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
