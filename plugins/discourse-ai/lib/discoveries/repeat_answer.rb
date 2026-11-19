# frozen_string_literal: true

module DiscourseAi
  module Discoveries
    class RepeatAnswer
      TTL = 24.hours.to_i
      MAX_ANSWERS_PER_USER = 10
      STORE_ANSWER_SCRIPT = <<~LUA
        local key, stored_order = KEYS[1], KEYS[2]
        local payload, ttl, limit = ARGV[1], ARGV[2], tonumber(ARGV[3])

        redis.call("SET", key, payload, "EX", ttl)
        for _, entry in ipairs(redis.call("LRANGE", stored_order, 0, -1)) do
          if entry == key or redis.call("EXISTS", entry) == 0 then
            redis.call("LREM", stored_order, 0, entry)
          end
        end

        local size = redis.call("RPUSH", stored_order, key)
        local evictions = 0
        for _ = 1, size - limit do
          local oldest = redis.call("LPOP", stored_order)
          evictions = evictions + redis.call("DEL", oldest)
        end
        redis.call("EXPIRE", stored_order, ttl)
        return evictions
      LUA

      def initialize(user:, query:, requested_scope:, scope:, agent:, llm:, settings:)
        fingerprint = [
          query.squish.downcase,
          requested_scope,
          scope,
          user.effective_locale,
          agent.cache_key_with_version,
          llm.cache_key_with_version,
          settings,
          SiteSetting.ai_ask_ai_keyword_search_enabled,
          SiteSetting.ai_ask_ai_semantic_search_enabled,
          SiteSetting.ai_ask_ai_search_categories,
          SiteSetting.ai_ask_ai_search_max_age_days,
          SiteSetting.ai_ask_ai_endorsed_reply_groups,
          SiteSetting.ai_ask_ai_external_sources,
          SiteSetting.ai_ask_ai_query_rewriter_agent,
          SiteSetting.enable_names,
        ]
        prefix = "discourse-ai:discoveries:repeat-answer:3:#{user.id}"
        @key = "#{prefix}:#{Digest::SHA256.hexdigest(fingerprint.to_json)}"
        @stored_order_key = "#{prefix}:order"
        @guardian = Guardian.new(user)
      end

      def read
        payload = Discourse.redis.get(@key)
        return if payload.blank?

        cached = JSON.parse(payload).symbolize_keys
        cached if visible_posts?(cached.fetch(:posts), @guardian)
      rescue JSON::ParserError, Redis::BaseError
        nil
      end

      def write(candidates:, **answer)
        return if candidates.any? { |candidate| ExternalSource.candidate?(candidate) }

        # Synthesis sees every candidate and passage, including posts it does not cite.
        posts =
          candidates
            .flat_map do |candidate|
              [candidate, *candidate["passages"]].map do |post|
                [post["post_id"], post["post_updated_at"]]
              end
            end
            .uniq
        return if !visible_posts?(posts, @guardian)

        answer[:sources] = answer
          .fetch(:sources)
          .map { |source| source.except("passages", "retrievals") }
        redis = Discourse.redis
        redis.eval(
          STORE_ANSWER_SCRIPT,
          keys: [redis.namespace_key(@key), redis.namespace_key(@stored_order_key)],
          argv: [
            answer.merge(posts:, cached_at: Time.current.iso8601).to_json,
            TTL,
            MAX_ANSWERS_PER_USER,
          ],
        )
      rescue Redis::BaseError
        nil
      end

      private

      def visible_posts?(sources, guardian)
        if sources.empty? || sources.any? { |id, updated_at| id.nil? || updated_at.nil? }
          return false
        end

        ids = sources.map(&:first)
        versions =
          Post
            .public_posts
            .visible
            .secured(Guardian.new)
            .secured(guardian)
            .where(id: ids)
            .pluck(:id, :updated_at)
            .to_h
        sources.all? { |id, updated_at| versions[id]&.iso8601(6) == updated_at }
      end
    end
  end
end
