# frozen_string_literal: true

module Jobs
  class GenerateDeQueryWithAi < ::Jobs::Base
    sidekiq_options retry: false

    CHANNEL_PREFIX = "/discourse-data-explorer/queries/ai-generation"

    def execute(args)
      @generation_id = args[:generation_id]

      return unless SiteSetting.data_explorer_enabled
      return unless SiteSetting.data_explorer_ai_queries_enabled

      user = User.find_by(id: args[:user_id])
      return if user.nil?

      query =
        DiscourseDataExplorer::QueryGeneration.call(
          user: user,
          ai_description: args[:ai_description],
          existing_sql: args[:existing_sql],
        )
      publish_complete(user, **query)
    rescue => e
      publish_error(user, e.message) if user
    ensure
      cleanup_redis
    end

    private

    def cleanup_redis
      if @generation_id
        Discourse.redis.del(DiscourseDataExplorer::AiQueryEnqueuer.redis_key(@generation_id))
      end
    end

    def publish_complete(user, sql:, name:, description:)
      MessageBus.publish(
        "#{CHANNEL_PREFIX}/#{@generation_id}",
        {
          status: "complete",
          generation_id: @generation_id,
          sql: sql,
          name: name,
          description: description,
        },
        user_ids: [user.id],
        max_backlog_age: DiscourseDataExplorer::AiQueryEnqueuer::REDIS_TTL,
      )
    end

    def publish_error(user, message)
      return if user.nil?

      MessageBus.publish(
        "#{CHANNEL_PREFIX}/#{@generation_id}",
        { status: "error", generation_id: @generation_id, error: message },
        user_ids: [user.id],
        max_backlog_age: DiscourseDataExplorer::AiQueryEnqueuer::REDIS_TTL,
      )
    end
  end
end
