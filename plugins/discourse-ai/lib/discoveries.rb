# frozen_string_literal: true

module DiscourseAi
  module Discoveries
    REQUEST_TTL = 30.minutes.to_i
    SITE_CONCURRENCY_LIMIT = 4
    WORK_LEASE_TTL = 25.seconds.to_i
    SEARCH_MODES = { search: 0, ask: 1 }.freeze
    SUMMARY_DETAILS = { quiet: 0, balanced: 1, prominent: 2 }.freeze
    MIN_RELATED_DISCUSSIONS = 2
    MAX_RELATED_DISCUSSIONS = 6
    REQUEST_ID_PATTERN =
      /\A[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/i
    PRIVATE_MESSAGE_FILTER =
      /(?:\A|\s)(?:in:(?:messages|personal|personal-direct|all-pms)|(?:group|personal)_messages:\S+)(?=\s|\z)/i
    BIND_REQUEST_SCRIPT = <<~LUA
      local existing_query = redis.call("GET", KEYS[1])
      if not existing_query then
        redis.call("SET", KEYS[1], ARGV[1], "EX", ARGV[3])
        redis.call("SET", KEYS[2], ARGV[2], "EX", ARGV[3])
        return 1
      end
      if existing_query == ARGV[1] then
        return 0
      end
      return -1
    LUA
    ADMIT_REQUEST_SCRIPT = <<~LUA
      redis.call("ZREMRANGEBYSCORE", KEYS[1], "-inf", ARGV[1])
      if redis.call("ZSCORE", KEYS[1], ARGV[2]) then
        redis.call("ZADD", KEYS[1], ARGV[3], ARGV[2])
        return 1
      end
      if redis.call("ZCARD", KEYS[1]) >= tonumber(ARGV[4]) then
        return 0
      end
      redis.call("ZADD", KEYS[1], ARGV[3], ARGV[2])
      redis.call("EXPIRE", KEYS[1], ARGV[5])
      return 1
    LUA

    class RequestConflict < StandardError
    end

    class << self
      def enabled_for_user?(user)
        eligible_for_user?(user) && user.user_option&.ai_search_discoveries != false
      end

      def eligible_for_user?(user)
        return false if user.nil?
        return false if !SiteSetting.discourse_ai_enabled || !SiteSetting.ai_discover_enabled
        return false if !user.in_any_groups?(SiteSetting.ai_discover_allowed_groups_map)
        return false if Guardian.new(user).is_silenced?
        return false if !retrieval_configured?

        agent = discover_agent
        if agent.nil? || !agent.enabled? || !user.in_any_groups?(agent.allowed_group_ids.to_a)
          return false
        end

        llm_model_id = agent.default_llm_id.presence || SiteSetting.ai_default_llm_model
        llm_model_id.present? && LlmModel.exists?(id: llm_model_id)
      end

      def valid_request_id?(request_id)
        request_id.to_s.match?(REQUEST_ID_PATTERN)
      end

      def private_message_query?(query)
        query.to_s.match?(PRIVATE_MESSAGE_FILTER)
      end

      def preferences_for(user)
        option = user.user_option
        summary_detail =
          SUMMARY_DETAILS.key(option.ai_search_discoveries_summary_detail) || :balanced
        related_count = option.ai_search_discoveries_related_count.to_i
        if !related_count.between?(MIN_RELATED_DISCUSSIONS, MAX_RELATED_DISCUSSIONS)
          related_count = MIN_RELATED_DISCUSSIONS
        end

        { show_summary: option.ai_search_discoveries_show_summary, summary_detail:, related_count: }
      end

      def bind_request(user_id:, request_id:, query:)
        normalized_query = query.to_s.unicode_normalize(:nfc).squish
        result =
          Discourse.redis.eval(
            BIND_REQUEST_SCRIPT,
            keys:
              [request_key(user_id, request_id), active_request_key(user_id)].map do |key|
                Discourse.redis.namespace_key(key)
              end,
            argv: [normalized_query, request_id.downcase, REQUEST_TTL],
          )

        return :created if result == 1
        return :existing if result == 0

        raise RequestConflict if result == -1
        raise "Unexpected Discoveries request binding result: #{result.inspect}"
      end

      def active_request?(user_id, request_id)
        Discourse.redis.get(active_request_key(user_id)) == request_id.to_s.downcase
      end

      def admit_request(user_id:, request_id:)
        now = Time.now.to_f
        token = work_token(user_id, request_id)
        result =
          Discourse.redis.eval(
            ADMIT_REQUEST_SCRIPT,
            keys: [Discourse.redis.namespace_key(in_flight_key)],
            argv: [now, token, now + WORK_LEASE_TTL, SITE_CONCURRENCY_LIMIT, WORK_LEASE_TTL * 2],
          )
        result == 1
      end

      def release_request(user_id:, request_id:)
        Discourse.redis.zrem(in_flight_key, work_token(user_id, request_id))
      end

      def store_result(user_id:, request_id:, query:, answer:, sources:, agent_id:)
        return if !valid_request_id?(request_id) || query.blank? || sources.blank?

        posts =
          Post
            .where(id: sources.map { |source| source.fetch("post_id") }, deleted_at: nil)
            .includes(:topic)
            .index_by(&:id)
        stored_sources =
          sources.filter_map do |source|
            post = posts[source.fetch("post_id")]
            topic = post&.topic
            next if topic.nil? || topic.id != source.fetch("topic_id")

            {
              post_id: post.id,
              topic_id: topic.id,
              category_id: topic.category_id,
              post_updated_at: post.updated_at.iso8601(6),
              topic_updated_at: topic.updated_at.iso8601(6),
            }
          end
        return if stored_sources.length != sources.length

        payload = { query:, answer:, sources: stored_sources, agent_id: }.to_json
        Discourse.redis.set(result_key(user_id, request_id), payload, ex: REQUEST_TTL)
      end

      def cached_result_for(user:, request_id:)
        return if user.nil? || !valid_request_id?(request_id)

        payload = Discourse.redis.get(result_key(user.id, request_id))
        return if payload.blank?

        result = JSON.parse(payload)
        sources = Array(result["sources"])
        return if result["query"].blank? || !result.key?("answer") || sources.empty?

        posts =
          Post
            .where(id: sources.pluck("post_id"), deleted_at: nil)
            .includes(topic: :category)
            .index_by(&:id)
        guardian = Guardian.new(user)
        visible_sources = []
        all_sources_visible =
          sources.all? do |source|
            post = posts[source["post_id"]]
            topic = post&.topic
            visible =
              topic && topic.id == source["topic_id"] && topic.archetype == Archetype.default &&
                topic.deleted_at.nil? && topic.visible? && guardian.can_see?(post) &&
                topic.category_id == source["category_id"] &&
                post.updated_at.iso8601(6) == source["post_updated_at"] &&
                topic.updated_at.iso8601(6) == source["topic_updated_at"]

            if visible
              visible_sources << source.merge("title" => topic.title, "url" => post.full_url)
            end
            visible
          end

        result.merge("sources" => visible_sources) if all_sources_visible
      rescue JSON::ParserError
        nil
      end

      private

      def discover_agent
        AiAgent.find_by_id_from_cache(SiteSetting.ai_discover_agent)
      end

      def request_key(user_id, request_id)
        "discourse-ai:discoveries:request:#{user_id}:#{request_id.downcase}"
      end

      def active_request_key(user_id)
        "discourse-ai:discoveries:active-request:#{user_id}"
      end

      def result_key(user_id, request_id)
        "discourse-ai:discoveries:result:#{user_id}:#{request_id.downcase}"
      end

      def in_flight_key
        "discourse-ai:discoveries:in-flight"
      end

      def work_token(user_id, request_id)
        "#{user_id}:#{request_id.downcase}"
      end

      def retrieval_configured?
        SiteSetting.ai_embeddings_enabled && SiteSetting.ai_embeddings_semantic_search_enabled
      end
    end
  end
end
