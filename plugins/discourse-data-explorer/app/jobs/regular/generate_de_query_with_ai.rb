# frozen_string_literal: true

module Jobs
  class GenerateDeQueryWithAi < ::Jobs::Base
    sidekiq_options retry: false

    CHANNEL_PREFIX = "/discourse-data-explorer/queries/ai-generation"

    def execute(args)
      @query_id = args[:query_id]

      return unless SiteSetting.data_explorer_enabled
      return unless SiteSetting.data_explorer_ai_queries_enabled

      query = DiscourseDataExplorer::Query.find_by(id: @query_id)
      user = User.find_by(id: args[:user_id])
      return if query.nil? || user.nil?

      agent_id =
        DiscourseAi::Agents::Agent.external_agent_id(DiscourseDataExplorer::AiQueryGenerator)
      agent_record = AiAgent.find_by(id: agent_id)
      if agent_record.nil?
        return(
          publish_error(
            query,
            user,
            I18n.t("discourse_data_explorer.ai.error_agent_not_configured"),
          )
        )
      end

      agent_klass = agent_record.class_instance
      bot = DiscourseAi::Agents::Bot.as(Discourse.system_user, agent: agent_klass.new)

      context =
        DiscourseAi::Agents::BotContext.new(
          messages: [{ type: :user, content: args[:ai_description] }],
          user: user,
          feature_name: "data_explorer_query_generation",
        )

      structured_output = nil
      result = +""
      bot.reply(context) do |partial, _, type|
        if type == :structured_output
          structured_output = partial
        elsif type.blank? && partial.is_a?(String)
          result << partial
        end
      end
      parsed = parse_structured_response(structured_output, result)

      if parsed[:sql].blank?
        return(
          publish_error(query, user, I18n.t("discourse_data_explorer.ai.error_no_sql_returned"))
        )
      end

      query.update!(
        sql: parsed[:sql].chomp(";").strip,
        name: parsed[:name].presence || args[:ai_description].to_s.truncate(60, separator: " "),
        description: parsed[:description].presence || args[:ai_description],
      )

      publish_complete(query, user)
    rescue => e
      publish_error(query, user, e.message) if query && user
    ensure
      cleanup_redis
    end

    private

    def cleanup_redis
      Discourse.redis.del(DiscourseDataExplorer::AiQueryEnqueuer.redis_key(@query_id)) if @query_id
    end

    def parse_structured_response(structured_output, text)
      if structured_output
        {
          sql: structured_output.read_buffered_property(:sql),
          name: structured_output.read_buffered_property(:name),
          description: structured_output.read_buffered_property(:description),
        }
      else
        parsed = JSON.parse(text.strip).symbolize_keys
        parsed.slice(:sql, :name, :description)
      end
    rescue JSON::ParserError
      { sql: text.strip, name: nil, description: nil }
    end

    def publish_complete(query, user)
      MessageBus.publish(
        "#{CHANNEL_PREFIX}/#{query.id}",
        { status: "complete", sql: query.sql, name: query.name, description: query.description },
        user_ids: [user.id],
        max_backlog_age: DiscourseDataExplorer::AiQueryEnqueuer::REDIS_TTL,
      )
    end

    def publish_error(query, user, message)
      return if query.nil? || user.nil?

      MessageBus.publish(
        "#{CHANNEL_PREFIX}/#{query.id}",
        { status: "error", error: message },
        user_ids: [user.id],
        max_backlog_age: DiscourseDataExplorer::AiQueryEnqueuer::REDIS_TTL,
      )
    end
  end
end
