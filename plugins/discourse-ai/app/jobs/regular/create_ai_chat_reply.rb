# frozen_string_literal: true

module ::Jobs
  class CreateAiChatReply < ::Jobs::Base
    sidekiq_options retry: false

    def execute(args)
      channel = ::Chat::Channel.find_by(id: args[:channel_id])
      return if channel.blank?

      message = ::Chat::Message.find_by(id: args[:message_id])
      return if message.blank?

      personaClass =
        DiscourseAi::Personas::Persona.find_by(id: args[:persona_id], user: message.user)
      return if personaClass.blank?

      user = User.find_by(id: personaClass.user_id)
      bot = DiscourseAi::Personas::Bot.as(user, persona: personaClass.new)

      DiscourseAi::AiBot::Playground.new(bot).reply_to_chat_message(
        message,
        channel,
        args[:context_post_ids],
      )
    end
  end
end
