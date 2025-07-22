# frozen_string_literal: true

module Jobs
  class StreamDiscoverReply < ::Jobs::Base
    sidekiq_options retry: false

    def execute(args)
      return if (user = User.find_by(id: args[:user_id])).nil?
      return if (query = args[:query]).blank?

      ai_persona_klass =
        AiPersona
          .all_personas(enabled_only: false)
          .find { |persona| persona.id == SiteSetting.ai_bot_discover_persona.to_i }

      if ai_persona_klass.nil? || !user.in_any_groups?(ai_persona_klass.allowed_group_ids.to_a)
        return
      end
      return if (llm_model = LlmModel.find_by(id: ai_persona_klass.default_llm_id)).nil?

      bot =
        DiscourseAi::Personas::Bot.as(
          Discourse.system_user,
          persona: ai_persona_klass.new,
          model: llm_model,
        )

      streamed_reply = +""
      start = Time.now

      base = { query: query, model_used: llm_model.display_name }

      context =
        DiscourseAi::Personas::BotContext.new(
          messages: [{ type: :user, content: query }],
          skip_tool_details: true,
        )

      bot.reply(context) do |partial|
        streamed_reply << partial

        # Throttle updates.
        if (Time.now - start > 0.3) || Rails.env.test?
          payload = base.merge(done: false, ai_discover_reply: streamed_reply)
          publish_update(user, payload)
          start = Time.now
        end
      end

      publish_update(user, base.merge(done: true, ai_discover_reply: streamed_reply))
    end

    def publish_update(user, payload)
      MessageBus.publish("/discourse-ai/ai-bot/discover", payload, user_ids: [user.id])
    end
  end
end
