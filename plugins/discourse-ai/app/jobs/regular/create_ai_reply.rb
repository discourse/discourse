# frozen_string_literal: true

module Jobs
  class CreateAiReply < ::Jobs::Base
    sidekiq_options retry: false

    def execute(args)
      return unless bot_user = User.find_by(id: args[:bot_user_id])
      return unless post = Post.includes(:topic).find_by(id: args[:post_id])
      reply_post = Post.find_by(id: args[:reply_post_id]) if args[:reply_post_id].present?
      return if args[:reply_post_id].present? && reply_post.nil?
      return if reply_post && reply_post.topic_id != post.topic_id
      persona_id = args[:persona_id]
      llm_model_id = args[:llm_model_id]

      begin
        persona = DiscourseAi::Personas::Persona.find_by(user: post.user, id: persona_id)
        raise DiscourseAi::Personas::Bot::BOT_NOT_FOUND if persona.nil?

        llm_model = LlmModel.find_by(id: llm_model_id.to_i) if !llm_model_id.to_i.zero?
        bot = DiscourseAi::Personas::Bot.as(bot_user, persona: persona.new, model: llm_model)

        DiscourseAi::AiBot::Playground.new(bot).reply_to(
          post,
          feature_name: "bot",
          existing_reply_post: reply_post,
        )
      rescue DiscourseAi::Personas::Bot::BOT_NOT_FOUND
        Rails.logger.warn(
          "Bot not found for post #{post.id} - perhaps persona was deleted or bot was disabled",
        )
      end
    end
  end
end
