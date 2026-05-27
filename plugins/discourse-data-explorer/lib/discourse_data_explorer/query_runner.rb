# frozen_string_literal: true

module DiscourseDataExplorer
  class QueryRunner
    def self.run(query, raw_params, current_user:, explain: false, limit: nil)
      query_params = parse_params(raw_params)
      opts = { current_user: }
      opts[:explain] = true if explain
      opts[:limit] = limit if limit

      result = DataExplorer.run_query(query, query_params, opts)

      return { error: result[:error], duration_secs: result[:duration_secs] } if result[:error]

      result_json =
        ResultFormatConverter.convert(:json, result, query_params:, explain:, current_user:)

      if cacheable?(query, explain:) && default_limit?(limit)
        cache_key_params = resolve_params(query, raw_params)
        QueryResultCache.write(query.id, cache_key_params, result_json)
      end

      result_json
    end

    def self.cached_result(query, raw_params)
      return nil unless cacheable?(query)
      params_hash = resolve_params(query, raw_params)
      QueryResultCache.read(query.id, params_hash)
    rescue MultiJson::ParseError
      nil
    end

    def self.invalidate(query_id)
      QueryResultCache.invalidate(query_id)
    end

    def self.cacheable?(query, explain: false)
      !explain && !query.params.any?(&:internal?)
    end

    def self.default_limit?(limit)
      limit.nil? || limit == SiteSetting.data_explorer_query_result_limit
    end

    def self.resolve_params(query, raw_params)
      parsed = parse_params(raw_params)
      if parsed.present?
        user_param_ids = query.params.reject(&:internal?).map(&:identifier)
        parsed.slice(*user_param_ids)
      else
        query.params.each_with_object({}) { |p, h| h[p.identifier] = p.default unless p.internal? }
      end
    end

    def self.parse_params(raw_params)
      return {} if raw_params.blank?
      parsed = raw_params.is_a?(String) ? MultiJson.load(raw_params) : raw_params
      parsed = parsed.to_unsafe_h if parsed.respond_to?(:to_unsafe_h)
      parsed.is_a?(Hash) ? parsed : {}
    end

    private_class_method :resolve_params, :cacheable?, :default_limit?
  end
end
