# frozen_string_literal: true

module Jobs
  class CreateAiReply < ::Jobs::Base
    sidekiq_options retry: false

    def execute(args)
      post = Post.includes(:topic).find_by(id: args[:post_id])
      return if post.blank?

      reply_post = Post.find_by(id: args[:reply_post_id]) if args[:reply_post_id].present?
      return if args[:reply_post_id].present? && reply_post.blank?
      return if reply_post && reply_post.topic_id != post.topic_id
      return if reply_post && !DiscourseAi::AiBot::EntryPoint.ai_response?(reply_post)

      authorization_user = authorization_user(args, post)
      return if authorization_user.blank?
      if !authorization_user.guardian.can_create_post_on_topic?(post.topic)
        return(
          report_failure(
            post,
            I18n.t("discourse_ai.ai_bot.errors.target_unavailable"),
            args,
            allow_new_post: false,
          )
        )
      end

      legacy_speaker = User.find_by(id: args[:bot_user_id])
      model_id = args[:llm_model_id].presence
      model_id ||= LlmModel.where(user_id: legacy_speaker.id).pick(:id) if legacy_speaker
      modality = post.topic.private_message? ? :personal_message : :topic_mention
      route =
        DiscourseAi::AiBot::ConversationRoute.resolve(
          authorization_user:,
          modality:,
          agent_id: args[:agent_id],
          llm_model_id: model_id,
          topic: post.topic,
          recipient_user: args[:agent_id].present? ? nil : legacy_speaker,
          selection_source: args[:model_selection_source]&.to_sym || :snapshot,
        )

      bot =
        DiscourseAi::Agents::Bot.as(route.speaker, agent: route.agent_class.new, model: route.model)

      DiscourseAi::AiBot::Playground.new(bot).reply_to(
        post,
        feature_name: "bot",
        existing_reply_post: reply_post,
        authorization_user_id: authorization_user.id,
      )
    rescue DiscourseAi::AiBot::ConversationRoute::Error => error
      report_failure(post, error.message, args, authorization_user:)
    rescue DiscourseAi::Agents::Bot::BOT_NOT_FOUND
      report_failure(
        post,
        I18n.t("discourse_ai.ai_bot.errors.agent_unavailable"),
        args,
        authorization_user:,
      )
    end

    private

    def authorization_user(args, post)
      if args.key?(:authorization_user_id)
        User.find_by(id: args[:authorization_user_id])
      else
        post.user
      end
    end

    def report_failure(post, details, args, authorization_user: nil, allow_new_post: true)
      Rails.logger.warn("Unable to create AI reply for post #{post&.id}: #{details}")
      return if post.blank?

      raw = I18n.t("discourse_ai.ai_bot.reply_error", details:)
      speaker = failure_speaker(post, args, authorization_user) if allow_new_post
      if speaker
        custom_fields =
          if speaker.id == Discourse.system_user.id
            {}
          else
            { DiscourseAi::AiBot::POST_AI_AGENT_ID_FIELD => args[:agent_id] }
          end
        PostCreator.create!(
          speaker,
          topic_id: post.topic_id,
          raw:,
          skip_validations: true,
          skip_guardian: true,
          custom_fields:,
        )
      end
      nil
    end

    def failure_speaker(post, args, authorization_user)
      return if authorization_user.blank?
      return if !authorization_user.guardian.can_create_post_on_topic?(post.topic)

      agent_record = AiAgent.find_by(id: args[:agent_id])
      captured_speaker = User.find_by(id: args[:bot_user_id])
      if captured_speaker&.active? && agent_record&.user_id == captured_speaker.id &&
           captured_speaker.guardian.can_create_post_on_topic?(post.topic)
        return captured_speaker
      end

      agent = DiscourseAi::Agents::Agent.find_by(user: authorization_user, id: args[:agent_id].to_i)
      if agent
        allowed =
          post.topic.private_message? ? agent.allow_personal_messages : agent.allow_topic_mentions
        speaker = agent_record&.user if allowed
        return speaker if speaker&.active? && speaker.guardian.can_create_post_on_topic?(post.topic)
      end

      Discourse.system_user
    end
  end
end
