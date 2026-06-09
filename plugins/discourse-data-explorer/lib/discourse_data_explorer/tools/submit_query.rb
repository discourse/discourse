# frozen_string_literal: true

module DiscourseDataExplorer
  module Tools
    class SubmitQuery < DiscourseAi::Agents::Tools::Tool
      CONTEXT_KEY = :data_explorer_generated_query
      VALIDATED_SQL_KEY = :data_explorer_validated_sql

      def self.signature
        {
          name: name,
          description:
            "Submits the final verified Data Explorer query after schema lookup and SQL validation are complete.",
          parameters: [
            {
              name: "name",
              description: "a short descriptive name for the query, under 60 characters",
              type: "string",
              required: true,
            },
            {
              name: "description",
              description: "a one-sentence description of what the query does",
              type: "string",
              required: true,
            },
            {
              name: "sql",
              description: "the verified SQL query, without a trailing semicolon",
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
        "submit_query"
      end

      def invoke
        @submitted = false
        if !validated_sql?
          return(
            {
              status: "error",
              error:
                "Before submitting the final query, call run_sql with the exact SQL you intend to submit and fix any errors.",
            }
          )
        end

        context.feature_context[CONTEXT_KEY] = {
          name: parameters[:name].to_s,
          description: parameters[:description].to_s,
          sql: normalized_sql(parameters[:sql]),
        }
        @submitted = true

        { status: "success" }
      end

      def chain_next_response?
        @submitted != true
      end

      protected

      def description_args
        { name: parameters[:name].to_s.truncate(100) }
      end

      private

      def validated_sql?
        submitted_sql = normalized_sql(parameters[:sql])
        validated_sql = normalized_sql(context.feature_context[VALIDATED_SQL_KEY])

        submitted_sql.present? && submitted_sql == validated_sql
      end

      def normalized_sql(sql)
        sql.to_s.strip.chomp(";").strip
      end
    end
  end
end
