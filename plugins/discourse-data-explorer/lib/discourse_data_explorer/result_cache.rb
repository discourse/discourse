# frozen_string_literal: true

module DiscourseDataExplorer
  class ResultCache
    TTL = 24.hours.to_i
    MAX_CACHE_SIZE = 100.kilobytes

    def self.cache_key(query_id, ph = nil)
      key = "data_explorer:result:#{query_id}"
      key += ":#{ph}" if ph.present?
      key
    end

    def self.params_hash(params)
      return nil if params.blank?
      Digest::SHA1.hexdigest(params.sort.to_json)[0..7]
    end

    # @param query [Query] the query to cache results for
    # @param query_params [Hash, nil] the query parameters used for this run
    # @param result_json [Hash] the serialized query result
    # @return [Boolean] true if cached, false if result exceeds MAX_CACHE_SIZE
    def self.set(query, query_params, result_json)
      ph = params_hash(query_params)
      data = { result: result_json, cached_at: Time.now.iso8601 }
      serialized = data.to_json
      return false if serialized.bytesize > MAX_CACHE_SIZE

      Discourse.redis.setex(cache_key(query.id, ph), TTL, serialized) if ph.present?
      Discourse.redis.setex(cache_key(query.id), TTL, serialized)
      true
    end

    def self.get(query, query_params = nil)
      ph = params_hash(query_params)
      raw = Discourse.redis.get(cache_key(query.id, ph))
      return nil if raw.blank?
      JSON.parse(raw, symbolize_names: false)
    end

    def self.invalidate(query)
      query_id = query.is_a?(Integer) ? query : query.id
      base_key = cache_key(query_id)
      keys = Discourse.redis.scan_each(match: "#{base_key}:*").to_a
      keys << base_key
      Discourse.redis.del(*keys) if keys.present?
    end
  end
end
