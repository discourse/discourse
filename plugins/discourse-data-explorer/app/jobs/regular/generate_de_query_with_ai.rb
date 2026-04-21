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

      agent_id =
        DiscourseAi::Agents::Agent.external_agent_id(DiscourseDataExplorer::AiQueryGenerator)
      agent_record = AiAgent.find_by(id: agent_id)
      if agent_record.nil?
        return(publish_error(user, I18n.t("discourse_data_explorer.ai.error_agent_not_configured")))
      end

      agent_klass = agent_record.class_instance
      bot = DiscourseAi::Agents::Bot.as(Discourse.system_user, agent: agent_klass.new)

      user_message = args[:ai_description]
      if args[:existing_sql].present?
        user_message =
          "#{args[:ai_description]}\n\nHere is the current SQL query to refine:\n```sql\n#{args[:existing_sql]}\n```"
      end

      context =
        DiscourseAi::Agents::BotContext.new(
          messages: [{ type: :user, content: user_message }],
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
        return(publish_error(user, I18n.t("discourse_data_explorer.ai.error_no_sql_returned")))
      end

      sql = parsed[:sql].chomp(";").strip
      name = parsed[:name].presence || args[:ai_description].to_s.truncate(60, separator: " ")
      description = parsed[:description].presence || args[:ai_description]

      query_results = run_generated_query(sql, user)

      publish_complete(user, sql: sql, name: name, description: description, results: query_results)
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

    def run_generated_query(sql, user)
      query = DiscourseDataExplorer::Query.new(sql: sql)
      result =
        DiscourseDataExplorer::DataExplorer.run_query(
          query,
          {},
          current_user: user,
          limit: SiteSetting.data_explorer_query_result_limit,
        )
      return nil if result[:error]
      json = DiscourseDataExplorer::ResultFormatConverter.convert(:json, result)
      # serialize relations for MessageBus transport
      json[:relations] = json[:relations]&.transform_values { |v| v.as_json }
      json
    rescue StandardError => e
      Rails.logger.warn("Data Explorer: failed to run generated query: #{e.message}")
      nil
    end

    def publish_complete(user, sql:, name:, description:, results: nil)
      payload = {
        status: "complete",
        generation_id: @generation_id,
        sql: sql,
        name: name,
        description: description,
      }
      payload[:results] = results if results

      MessageBus.publish(
        "#{CHANNEL_PREFIX}/#{@generation_id}",
        payload,
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
