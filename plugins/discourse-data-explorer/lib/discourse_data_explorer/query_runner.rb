# frozen_string_literal: true

module DiscourseDataExplorer
  class QueryRunner
    class << self
      def run(query, raw_params, current_user:, explain: false, limit: nil)
        query_params = parse_params(raw_params)
        opts = { current_user: }
        opts[:explain] = true if explain
        opts[:limit] = limit if limit

        result = DataExplorer.run_query(query, query_params, opts)

        return { error: result[:error], duration_secs: result[:duration_secs] } if result[:error]

        result_json =
          ResultFormatConverter.convert(:json, result, query_params:, explain:, current_user:)

        if query.id.present? && cacheable?(query, explain:) && default_limit?(limit)
          cache_key_params = resolve_params(query, query_params)
          QueryResultCache.write(query.id, current_user, cache_key_params, result_json)
        end

        result_json
      end

      def cached_result(...)
        cached_entry(...).try { it.attributes.deep_symbolize_keys }
      end

      def cached_entry(query, raw_params, current_user:, max_age: nil)
        return nil unless cacheable?(query)

        QueryResultCache.read_result(
          query.id,
          current_user,
          resolve_params(query, parse_params(raw_params)),
          max_age:,
        )
      rescue MultiJson::ParseError
        nil
      end

      def invalidate(query_id)
        QueryResultCache.invalidate(query_id)
      end

      def cacheable?(query, explain: false)
        !explain && !query.params.any?(&:internal?)
      end

      def parse_params(raw_params)
        return {} if raw_params.blank?
        parsed = raw_params.is_a?(String) ? MultiJson.load(raw_params) : raw_params
        parsed = parsed.to_unsafe_h if parsed.respond_to?(:to_unsafe_h)
        parsed.is_a?(Hash) ? parsed : {}
      end

      private

      def default_limit?(limit)
        limit.nil? || limit == SiteSetting.data_explorer_query_result_limit
      end

      def resolve_params(query, parsed)
        if parsed.present?
          user_param_ids = query.params.reject(&:internal?).map(&:identifier)
          parsed.slice(*user_param_ids)
        else
          query
            .params
            .each_with_object({}) { |p, h| h[p.identifier] = p.default unless p.internal? }
        end
      end
    end
  end
end
