# frozen_string_literal: true

module Jobs
  class GenerateDeQueryWithAi < ::Jobs::Base
    sidekiq_options retry: false

    CHANNEL_PREFIX = "/discourse-data-explorer/queries/ai-generation"
    REDIS_PREFIX = "data_explorer_ai_generating"

    def execute(args)
      @query_id = args[:query_id]

      return unless SiteSetting.data_explorer_enabled
      return unless SiteSetting.data_explorer_ai_queries_enabled

      query = DiscourseDataExplorer::Query.find_by(id: @query_id)
      user = User.find_by(id: args[:user_id])
      return cleanup_redis if query.nil? || user.nil?

      agent_id =
        DiscourseAi::Agents::Agent.external_agent_id(DiscourseDataExplorer::AiQueryGenerator)
      agent_record = AiAgent.find_by(id: agent_id)
      if agent_record.nil?
        cleanup_redis
        return publish_error(query, user, "AI agent not configured")
      end

      agent_klass = agent_record.class_instance
      bot = DiscourseAi::Agents::Bot.as(Discourse.system_user, agent: agent_klass.new)

      context =
        DiscourseAi::Agents::BotContext.new(
          messages: [{ type: :user, content: args[:ai_description] }],
          user: user,
          feature_name: "data_explorer_query_generation",
        )

      result = bot.reply(context) { |partial, _, type| }
      parsed = parse_response(result)

      if parsed[:sql].blank?
        cleanup_redis
        return publish_error(query, user, "AI did not return valid SQL")
      end

      query.update!(
        sql: parsed[:sql].chomp(";").strip,
        name: parsed[:name].presence || args[:ai_description].to_s.truncate(60, separator: " "),
        description: parsed[:description].presence || args[:ai_description],
      )

      cleanup_redis
      publish_complete(query, user)
    rescue => e
      cleanup_redis
      publish_error(query, user, e.message) if query && user
    end

    private

    def cleanup_redis
      Discourse.redis.del("#{REDIS_PREFIX}:#{@query_id}") if @query_id
    end

    def parse_response(result)
      text =
        result
          .select { |segment| segment.is_a?(Array) && segment[0].is_a?(String) }
          .last
          &.first
          .to_s
          .strip

      JSON.parse(text).symbolize_keys
    rescue JSON::ParserError
      # fallback if the agent didn't return valid JSON
      { sql: text, name: nil, description: nil }
    end

    def publish_complete(query, user)
      MessageBus.publish(
        "#{CHANNEL_PREFIX}/#{query.id}",
        { status: "complete", sql: query.sql, name: query.name, description: query.description },
        user_ids: [user.id],
        max_backlog_age: 120,
      )
    end

    def publish_error(query, user, message)
      return if query.nil? || user.nil?

      MessageBus.publish(
        "#{CHANNEL_PREFIX}/#{query.id}",
        { status: "error", error: message },
        user_ids: [user.id],
        max_backlog_age: 120,
      )
    end
  end
end
