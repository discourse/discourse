# frozen_string_literal: true

module DiscourseAi
  module AiHelper
    class ChatThreadTitler
      FEATURE_NAME = "chat_thread_titles"

      def initialize(thread)
        @thread = thread
      end

      def suggested_title
        content = thread_content(@thread)
        return nil if content.blank?

        result = call_llm(content)
        return nil if result.blank?

        cleanup(result)
      end

      private

      def call_llm(thread_content)
        ai_agent = AiAgent.find_by_id_from_cache(SiteSetting.ai_helper_chat_thread_title_agent)
        return nil if ai_agent.blank?

        agent_klass = ai_agent.class_instance
        llm_model = Assistant.find_ai_helper_model(FEATURE_NAME, agent_klass)
        return nil if llm_model.blank?

        agent = agent_klass.new
        user = Discourse.system_user

        bot = DiscourseAi::Agents::Bot.as(user, agent: agent, model: llm_model)

        context =
          DiscourseAi::Agents::BotContext.new(
            user: user,
            skip_show_thinking: true,
            feature_name: FEATURE_NAME,
            messages: [{ type: :user, content: thread_content }],
          )

        result = +""
        bot.reply(context) do |partial, _, type|
          if type == :structured_output
            title = partial.read_buffered_property(:title)
            result << title if title.present?
          elsif type.blank?
            result << partial
          end
        end

        result.presence
      end

      def cleanup(title)
        title
          .to_s
          .strip
          .split("\n")
          .first
          .to_s
          .then { it.match?(/^(["']).*\1$/) ? it[1..-2] : it }
          .truncate(100, separator: " ")
      end

      def thread_content(thread)
        thread
          .chat_messages
          .joins(:user)
          .pluck(:username, :message)
          .map { |username, message| "#{username}: #{message}" }
          .join("\n")
      end

      attr_reader :thread
    end
  end
end
