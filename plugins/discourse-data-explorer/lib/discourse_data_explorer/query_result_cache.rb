# frozen_string_literal: true

module DiscourseDataExplorer
  class QueryResultCache
    CACHE_TTL = 24.hours.to_i
    MAX_CACHE_SIZE = 200.kilobytes
    MAX_CACHE_ENTRIES = 50

    class << self
      def visibility_scope(user)
        return "admin" if user.admin? && !SiteSetting.suppress_secured_categories_from_admin

        user.id
      end

      def cache_key(query_id, user, params_hash)
        Key.for(query_id, user, params_hash).to_s
      end

      def read(query_id, user, params_hash, max_age: nil)
        read_result(query_id, user, params_hash, max_age:)&.attributes
      end

      def read_result(query_id, user, params_hash, max_age: nil)
        read_key(Key.for(query_id, user, params_hash), max_age:)
      end

      def read_entry(key, user, max_age: nil)
        return unless key.visible_to?(user)
        read_key(key, max_age:)
      end

      def write(query_id, user, params_hash, result_json)
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

      def invalidate(query_id)
        keys =
          Discourse.redis.scan_each(match: "data_explorer:result:#{query_id}:*", count: 1000).to_a
        Discourse.redis.del(*keys) if keys.present?
      end

      def cache_index_key(query_id)
        "data_explorer:result:#{query_id}:keys"
      end

      private

      def read_key(key, max_age:)
        stored_result(key).try { it if it.fresh?(max_age:) }
      end

      def stored_result(key)
        Discourse
          .redis
          .get(key.to_s)
          .try { MultiJson.load(it) }
          .try { CachedResult.new(identity: key, attributes: it) }
      rescue MultiJson::ParseError
        nil
      end
    end
  end
end
