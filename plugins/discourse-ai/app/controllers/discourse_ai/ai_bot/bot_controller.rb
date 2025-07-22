# frozen_string_literal: true

module DiscourseAi
  module AiBot
    class BotController < ::ApplicationController
      requires_plugin ::DiscourseAi::PLUGIN_NAME
      requires_login

      def show_debug_info_by_id
        log = AiApiAuditLog.find(params[:id])
        raise Discourse::NotFound if !log.topic

        guardian.ensure_can_debug_ai_bot_conversation!(log.topic)
        render json: AiApiAuditLogSerializer.new(log, root: false), status: 200
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

        render json: AiApiAuditLogSerializer.new(debug_info, root: false), status: 200
      end

      def stop_streaming_response
        post = Post.find(params[:post_id])
        guardian.ensure_can_see!(post)

        Discourse.redis.del("gpt_cancel:#{post.id}")

        render json: {}, status: 200
      end

      def show_bot_username
        bot_user = DiscourseAi::AiBot::EntryPoint.find_user_from_model(params[:username])
        raise Discourse::InvalidParameters.new(:username) if !bot_user

        render json: { bot_username: bot_user.username_lower }, status: 200
      end

      def discover
        ai_persona =
          AiPersona
            .all_personas(enabled_only: false)
            .find { |persona| persona.id == SiteSetting.ai_bot_discover_persona.to_i }

        if ai_persona.nil? || !current_user.in_any_groups?(ai_persona.allowed_group_ids.to_a)
          raise Discourse::InvalidAccess.new
        end

        if ai_persona.default_llm_id.blank?
          render_json_error "Discover persona is missing a default LLM model.", status: 503
          return
        end

        query = params[:query]
        raise Discourse::InvalidParameters.new("Missing query to discover") if query.blank?

        RateLimiter.new(current_user, "ai_bot_discover_#{current_user.id}", 3, 1.minute).performed!

        Jobs.enqueue(:stream_discover_reply, user_id: current_user.id, query: query)

        render json: {}, status: 200
      end

      def discover_continue_convo
        raise Discourse::InvalidParameters.new("user_id") if !params[:user_id]
        raise Discourse::InvalidParameters.new("query") if !params[:query]
        raise Discourse::InvalidParameters.new("context") if !params[:context]

        user = User.find(params[:user_id])

        bot_user_id = AiPersona.find_by(id: SiteSetting.ai_bot_discover_persona).user_id
        bot_username = User.find_by(id: bot_user_id).username

        query = params[:query]
        context = "[quote]\n#{params[:context]}\n[/quote]"

        post =
          PostCreator.create!(
            user,
            title:
              I18n.t("discourse_ai.ai_bot.discoveries.continue_conversation.title", query: query),
            raw:
              I18n.t(
                "discourse_ai.ai_bot.discoveries.continue_conversation.raw",
                query: query,
                context: context,
              ),
            archetype: Archetype.private_message,
            target_usernames: bot_username,
            skip_validations: true,
          )

        render json: success_json.merge(topic_id: post.topic_id)
      rescue StandardError => e
        render json: failed_json.merge(errors: [e.message]), status: 422
      end
    end
  end
end
