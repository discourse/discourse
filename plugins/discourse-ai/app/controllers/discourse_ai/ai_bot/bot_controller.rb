# frozen_string_literal: true

module DiscourseAi
  module AiBot
    class BotController < ::ApplicationController
      include AiCreditLimitHandler

      requires_plugin PLUGIN_NAME
      requires_login

      def show_debug_info_by_id
        log = AiApiAuditLog.find(params[:id])
        raise Discourse::NotFound if !log.topic

        guardian.ensure_can_debug_ai_bot_conversation!(log.topic)
        render json: AiApiAuditLogSerializer.new(log, root: false), status: :ok
      end

      def show_debug_info
        post = Post.find(params[:post_id])
        guardian.ensure_can_debug_ai_bot_conversation!(post)

        posts =
          Post
            .where("post_number <= ?", post.post_number)
            .where(topic_id: post.topic_id)
            .order("post_number DESC")

        debug_info = AiApiAuditLog.where(post: posts).order(created_at: :desc).first

        render json: AiApiAuditLogSerializer.new(debug_info, root: false), status: :ok
      end

      def stop_streaming_response
        post = Post.find(params[:post_id])
        guardian.ensure_can_see!(post)

        Discourse.redis.del("gpt_cancel:#{post.id}")

        render json: {}, status: :ok
      end

      def retry_response
        post = Post.find(params[:post_id])
        guardian.ensure_can_see!(post)

        if !DiscourseAi::AiBot::EntryPoint.all_bot_ids.include?(post.user_id)
          raise Discourse::InvalidParameters.new(:post_id)
        end

        prompt_post = find_prompt_post(post)
        raise Discourse::NotFound if prompt_post.blank?

        guardian.ensure_can_see!(prompt_post)

        persona_id = retry_persona_id(post, prompt_post)
        llm_model_id = post.custom_fields[DiscourseAi::AiBot::POST_AI_LLM_MODEL_ID_FIELD]

        args = {
          post_id: prompt_post.id,
          bot_user_id: post.user_id,
          persona_id: persona_id,
          reply_post_id: post.id,
        }

        args[:llm_model_id] = llm_model_id.to_i if !llm_model_id.to_i.zero?

        Jobs.enqueue(:create_ai_reply, args)

        render json: success_json
      end

      def show_bot_username
        bot_user = DiscourseAi::AiBot::EntryPoint.find_user_from_model(params[:username])
        raise Discourse::InvalidParameters.new(:username) if !bot_user

        render json: { bot_username: bot_user.username_lower }, status: :ok
      end

      private

      def find_prompt_post(bot_reply_post)
        bot_ids = DiscourseAi::AiBot::EntryPoint.all_bot_ids

        bot_reply_post
          .topic
          .posts
          .where("post_number < ?", bot_reply_post.post_number)
          .where.not(user_id: bot_ids)
          .reorder(post_number: :desc)
          .first
      end

      def retry_persona_id(bot_reply_post, prompt_post)
        persona_id =
          bot_reply_post.custom_fields[DiscourseAi::AiBot::POST_AI_PERSONA_ID_FIELD].presence

        persona_id ||= prompt_post.topic.custom_fields["ai_persona_id"].presence

        if persona_id.blank?
          persona_name = prompt_post.topic.custom_fields["ai_persona"].presence
          persona_id = AiPersona.find_by(name: persona_name)&.id if persona_name.present?
        end

        persona_id ||= DiscourseAi::Personas::General.id
        persona_id.to_i
      end
    end
  end
end
