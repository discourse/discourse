# frozen_string_literal: true

module DiscourseAi
  module Discord::Bot
    class AgentReplier < Base
      def initialize(body)
        super(body)

        @agent_class =
          AiAgent
            .all_agents(enabled_only: false)
            .find { |p| p.id == SiteSetting.ai_discord_search_agent.to_i }

        @agent_user = User.find_by(id: @agent_class&.user_id)
        return if @agent_class.nil? || @agent_user.nil?

        @agent = @agent_class.new
        @bot =
          DiscourseAi::Agents::Bot.as(
            @agent_user,
            agent: @agent,
            model: LlmModel.find(@agent.class.default_llm_id || SiteSetting.ai_default_llm_model),
          )
      end

      def handle_interaction!
        if @bot.nil?
          return create_reply(I18n.t("discourse_ai.discord.configuration.agent_user_required"))
        end

        last_update_sent_at = Time.now - 1
        reply = +""

        context =
          DiscourseAi::Agents::BotContext.new(
            user: @agent_user,
            messages: [{ type: :user, content: @query }],
            skip_show_thinking: true,
          )

        full_reply =
          @bot.reply(context) do |partial, _something|
            reply << partial
            next if reply.blank?

            if @reply_response.nil?
              create_reply(wrap_links(reply.dup))
            elsif @last_update_response.nil?
              update_reply(wrap_links(reply.dup))
            elsif Time.now - last_update_sent_at > 1
              update_reply(wrap_links(reply.dup))
              last_update_sent_at = Time.now
            end
          end

        discord_reply = wrap_links(full_reply.last.first)

        if @reply_response.nil?
          create_reply(discord_reply)
        else
          update_reply(discord_reply)
        end
      end

      def wrap_links(text)
        text.gsub(%r{(?<url>https?://[^\s]+)}, "<\\k<url>>")
      end
    end
  end
end
