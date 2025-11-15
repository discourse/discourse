# frozen_string_literal: true

module Jobs
  class StreamDiscoverReply < ::Jobs::Base
    sidekiq_options retry: false

    def execute(args)
      return if !SiteSetting.ai_discover_enabled
      return if (user = User.find_by(id: args[:user_id])).nil?
      return if (query = args[:query]).blank?

      ai_persona_klass =
        AiPersona
          .all_personas(enabled_only: false)
          .find { |persona| persona.id == SiteSetting.ai_discover_persona.to_i }

      if ai_persona_klass.nil? || !user.in_any_groups?(ai_persona_klass.allowed_group_ids.to_a)
        return
      end

      llm_model_id = ai_persona_klass.default_llm_id || SiteSetting.ai_default_llm_model
      return if (llm_model = LlmModel.find_by(id: llm_model_id)).nil?

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
          skip_show_thinking: true,
          feature_name: "discover",
        )

      begin
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
      rescue LlmCreditAllocation::CreditLimitExceeded => e
        publish_error_update(user, e)
      end
    end

    def publish_update(user, payload)
      MessageBus.publish("/discourse-ai/discoveries", payload, user_ids: [user.id])
    end

    def publish_error_update(user, exception)
      allocation = exception.allocation

      details = {}
      if allocation
        details[:reset_time_relative] = allocation.relative_reset_time
        details[:reset_time_absolute] = allocation.formatted_reset_time
      end

      payload = {
        error: true,
        error_type: "credit_limit_exceeded",
        message: exception.message,
        details: details,
        done: true,
      }

      MessageBus.publish("/discourse-ai/discoveries", payload, user_ids: [user.id])
    end
  end
end
