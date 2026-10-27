# frozen_string_literal: true

module Jobs
  class CreateAiChatReply < ::Jobs::Base
    sidekiq_options retry: false

    def execute(args)
      channel = ::Chat::Channel.find_by(id: args[:channel_id])
      message = ::Chat::Message.find_by(id: args[:message_id])
      return if channel.blank? || message.blank? || message.chat_channel_id != channel.id

      authorization_user =
        if args.key?(:authorization_user_id)
          User.find_by(id: args[:authorization_user_id])
        else
          message.user
        end
      return if authorization_user.blank? || authorization_user.id != message.user_id
      return if !authorization_user.guardian.can_join_chat_channel?(channel)
      return if !authorization_user.guardian.can_create_chat_message?

      modality = channel.direct_message_channel? ? :chat_direct_message : :chat_channel_mention
      route =
        DiscourseAi::AiBot::ConversationRoute.resolve(
          authorization_user:,
          modality:,
          agent_id: args[:agent_id],
          llm_model_id: args[:llm_model_id],
          selection_source: args[:model_selection_source]&.to_sym || :snapshot,
          allow_general_fallback: false,
        )
      bot =
        DiscourseAi::Agents::Bot.as(route.speaker, agent: route.agent_class.new, model: route.model)

      DiscourseAi::AiBot::Playground.new(bot).reply_to_chat_message(
        message,
        channel,
        args[:context_post_ids],
      )
    rescue DiscourseAi::AiBot::ConversationRoute::Error => error
      Rails.logger.warn(
        "Unable to create AI chat reply for message #{message&.id}: #{error.message}",
      )
      DiscourseAi::AiBot::Playground.report_chat_route_error(
        message:,
        channel:,
        authorization_user:,
        agent_id: args[:agent_id],
        speaker_id: args[:bot_user_id],
        details: error.message,
      )
    rescue DiscourseAi::Agents::Bot::BOT_NOT_FOUND
      details = I18n.t("discourse_ai.ai_bot.errors.agent_unavailable")
      Rails.logger.warn("Unable to create AI chat reply for message #{message&.id}: #{details}")
      DiscourseAi::AiBot::Playground.report_chat_route_error(
        message:,
        channel:,
        authorization_user:,
        agent_id: args[:agent_id],
        speaker_id: args[:bot_user_id],
        details:,
      )
    end
  end
end
