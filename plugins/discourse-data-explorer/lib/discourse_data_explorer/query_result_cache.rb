# frozen_string_literal: true

module DiscourseDataExplorer
  class QueryResultCache
    CACHE_TTL = 24.hours.to_i
    MAX_CACHE_SIZE = 100.kilobytes

    def self.cache_key(query_id, params_hash)
      h = params_hash || {}
      h = h.to_unsafe_h if h.respond_to?(:to_unsafe_h)
      normalized = h.sort.to_h.to_json
      digest = Digest::SHA256.hexdigest(normalized)
      "data_explorer:result:#{query_id}:#{digest}"
    end

    def self.read(query_id, params_hash)
      key = cache_key(query_id, params_hash)
      raw = Discourse.redis.get(key)
      return nil if raw.nil?
      MultiJson.load(raw)
    end

    def self.write(query_id, params_hash, result_json)
      payload = result_json.merge("cached_at" => Time.now.utc.iso8601)
      serialized = MultiJson.dump(payload)
      return false if serialized.bytesize > MAX_CACHE_SIZE

      key = cache_key(query_id, params_hash)
      Discourse.redis.setex(key, CACHE_TTL, serialized)
      true
    end

    def self.invalidate(query_id)
      keys = Discourse.redis.scan_each(match: "data_explorer:result:#{query_id}:*").to_a
      Discourse.redis.del(*keys) if keys.present?
    end
  end
end
