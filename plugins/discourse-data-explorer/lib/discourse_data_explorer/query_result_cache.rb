# frozen_string_literal: true

module DiscourseDataExplorer
  class QueryResultCache
    CACHE_TTL = 24.hours.to_i
    MAX_CACHE_SIZE = 200.kilobytes
    MAX_CACHE_ENTRIES = 50

    def self.visibility_scope(user)
      return "admin" if user.admin? && !SiteSetting.suppress_secured_categories_from_admin

      user.id
    end

    def self.cache_key(query_id, user, params_hash)
      digest = Digest::SHA256.hexdigest((params_hash || {}).sort.to_h.to_json)
      "data_explorer:result:#{query_id}:#{visibility_scope(user)}:#{digest}"
    end

    def self.read(query_id, user, params_hash, max_age: nil)
      raw = Discourse.redis.get(cache_key(query_id, user, params_hash))
      return nil if raw.nil?

      result = MultiJson.load(raw)
      return nil if max_age && !within_max_age?(result, max_age)

      result
    end

    def self.within_max_age?(result, max_age)
      Time.iso8601(result["cached_at"]) >= max_age.ago
    rescue ArgumentError, TypeError
      false
    end
    private_class_method :within_max_age?

    def self.write(query_id, user, params_hash, result_json)
      payload = result_json.merge("cached_at" => Time.now.utc.iso8601)
      serialized = MultiJson.dump(payload)
      return false if serialized.bytesize > MAX_CACHE_SIZE

      key = cache_key(query_id, user, params_hash)
      index_key = cache_index_key(query_id)
      now = Time.now.to_f

      _pruned, score, oldest =
        Discourse.redis.pipelined do |redis|
          redis.zremrangebyscore(index_key, "-inf", now - CACHE_TTL)
          redis.zscore(index_key, key)
          redis.zrange(index_key, 0, -MAX_CACHE_ENTRIES)
        end
      evicted = score.nil? ? Array(oldest) : []

      Discourse.redis.multi do |redis|
        if evicted.present?
          redis.del(evicted)
          redis.zrem(index_key, evicted)
        end

        redis.setex(key, CACHE_TTL, serialized)
        redis.zadd(index_key, now, key)
        redis.expire(index_key, CACHE_TTL)
      end
      true
    end

    def self.invalidate(query_id)
      keys =
        Discourse.redis.scan_each(match: "data_explorer:result:#{query_id}:*", count: 1000).to_a
      Discourse.redis.del(*keys) if keys.present?
    end

    def self.cache_index_key(query_id)
      "data_explorer:result:#{query_id}:keys"
    end
  end
end
