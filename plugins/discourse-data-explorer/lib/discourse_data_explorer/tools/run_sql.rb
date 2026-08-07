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
        if !context.user&.admin?
          return error_response(I18n.t("discourse_data_explorer.errors.tool_not_allowed"))
        end

        sql = parameters[:sql].to_s.strip
        return error_response("SQL query is empty") if sql.blank?

        query = DiscourseDataExplorer::Query.new(name: "AI tool query", sql: sql)
        params_error = undeclared_params_error(query)
        return error_response(params_error) if params_error

        query_params =
          DiscourseDataExplorer::AiQueryParams.sample_for(query, current_user: context.user)
        result =
          DiscourseDataExplorer::DataExplorer.run_query(
            query,
            query_params,
            current_user: context.user,
            limit: MAX_ROWS + 1,
          )

        return error_response(result[:error].message) if result[:error]

        context.feature_context[DiscourseDataExplorer::Tools::SubmitQuery::VALIDATED_SQL_KEY] = sql

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

        {
          status: "success",
          columns: columns,
          rows: rows,
          row_count: total_rows,
          params_used: query_params,
          next_action:
            "Call submit_query with the exact same sql value after choosing a name and description. Do not call run_sql again with identical SQL.",
        }
      end

      protected

      def description_args
        { sql: parameters[:sql].to_s.truncate(100) }
      end

      private

      def undeclared_params_error(query)
        declared_params = query.params.map(&:identifier).to_set
        used_params = query.sql.scan(/(?<!:):([a-zA-Z][a-zA-Z0-9_]*)/).flatten.to_set
        undeclared_params = used_params - declared_params

        return if undeclared_params.blank?

        formatted_params = undeclared_params.sort.map { |param| ":#{param}" }.to_sentence

        "The SQL uses #{formatted_params}, but #{undeclared_params.one? ? "it is" : "they are"} not declared in a `-- [params]` block. Add parameter declarations at the top of the query before testing it again."
      end
    end
  end
end
