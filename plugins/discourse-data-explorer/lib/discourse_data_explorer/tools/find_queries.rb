# frozen_string_literal: true

module DiscourseDataExplorer
  module Tools
    class FindQueries < DiscourseAi::Agents::Tools::Tool
      DEFAULT_LIMIT = 5
      MAX_LIMIT = 8
      MAX_SEARCHABLE_QUERIES = 200
      MAX_SQL_LENGTH = 2_000

      def self.signature
        {
          name: name,
          description:
            "Finds existing Data Explorer queries that may be useful examples for the user's request. Use this for inspiration before writing SQL; do not copy results blindly.",
          parameters: [
            {
              name: "search",
              description:
                "short search phrase describing the report or query pattern to find, for example: active members, tag usage, group replies",
              type: "string",
              required: true,
            },
            {
              name: "limit",
              description: "maximum number of example queries to return",
              type: "integer",
              required: false,
            },
          ],
        }
      end

      def self.custom?
        true
      end

      def self.name
        "find_queries"
      end

      def invoke
        if !context.user&.admin?
          return error_response(I18n.t("discourse_data_explorer.errors.tool_not_allowed"))
        end

        search = parameters[:search].to_s.strip
        limit = requested_limit
        matches = matching_queries(search).first(limit)

        {
          search: search,
          query_count: matches.length,
          queries: matches.map { |query| serialize_query(query) },
          note:
            "Use these existing Data Explorer queries as examples for SQL patterns, joins, params, and filters. Still inspect schema and validate the final SQL with run_sql.",
        }
      end

      protected

      def description_args
        { search: parameters[:search].to_s.truncate(100) }
      end

      private

      def requested_limit
        limit = parameters[:limit].presence&.to_i || DEFAULT_LIMIT
        limit.clamp(1, MAX_LIMIT)
      end

      def matching_queries(search)
        candidates = visible_saved_queries + unpersisted_default_queries
        candidates.uniq!(&:id)

        scored =
          candidates.filter_map do |query|
            score = score_query(query, search)
            next if search.present? && score <= 0

            [query, score]
          end

        scored
          .sort_by { |query, score| [-score, query.last_run_at ? 0 : 1, query.name.to_s] }
          .map(&:first)
      end

      def visible_saved_queries
        DiscourseDataExplorer::Query
          .where(hidden: false)
          .order(Arel.sql("last_run_at DESC NULLS LAST"), updated_at: :desc)
          .limit(MAX_SEARCHABLE_QUERIES)
          .to_a
      end

      def unpersisted_default_queries
        DiscourseDataExplorer::Query.unpersisted_defaults
      end

      def score_query(query, search)
        return 1 if search.blank?

        phrase = normalize(search)
        terms = phrase.split.uniq
        score = 0
        fields = {
          normalize(query.name) => 5,
          normalize(query.description) => 3,
          normalize(query.sql) => 1,
        }

        fields.each do |text, weight|
          next if text.blank?

          score += weight * 3 if text.include?(phrase)
          terms.each { |term| score += weight if text.include?(term) }
        end

        score
      end

      def normalize(value)
        value.to_s.downcase.gsub(/[^a-z0-9_]+/, " ").squish
      end

      def serialize_query(query)
        {
          id: query.id,
          name: query.name,
          description: query.description,
          is_default: query.id.to_i < 0,
          last_run_at: query.last_run_at&.iso8601,
          params: query.params.map(&:to_hash),
          sql: truncate_sql(query.sql),
        }
      end

      def truncate_sql(sql)
        return sql if sql.length <= MAX_SQL_LENGTH

        "#{sql[0...MAX_SQL_LENGTH]}\n-- SQL truncated by find_queries"
      end
    end
  end
end
