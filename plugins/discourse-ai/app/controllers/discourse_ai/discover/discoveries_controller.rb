# frozen_string_literal: true

module DiscourseAi
  module Discover
    class DiscoveriesController < ::ApplicationController
      include AiCreditLimitHandler

      requires_plugin PLUGIN_NAME
      requires_login
      before_action :check_permissions

      def reply
        if ai_discover_persona.default_llm_id.blank? && SiteSetting.ai_default_llm_model.blank?
          render_json_error "Discover persona is missing a default LLM model.", status: 503
          return
        end

        query = params[:query]
        raise Discourse::InvalidParameters.new("Missing query to discover") if query.blank?

        RateLimiter.new(current_user, "ai_discover_#{current_user.id}", 8, 1.minute).performed!

        Jobs.enqueue(:stream_discover_reply, user_id: current_user.id, query: query)

        render json: {}, status: :ok
      end

      def continue_convo
        raise Discourse::InvalidParameters.new("query") if !params[:query]
        raise Discourse::InvalidParameters.new("context") if !params[:context]

        bot_user_id = ai_discover_persona.user_id
        bot_username = User.find_by(id: bot_user_id).username

        RateLimiter.new(
          current_user,
          "ai_discover_#{current_user.id}_continue_convo",
          3,
          1.minute,
        ).performed!

        query = params[:query]
        context = "[quote]\n#{params[:context]}\n[/quote]"

        post =
          PostCreator.create!(
            current_user,
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
        render json: failed_json.merge(errors: [e.message]), status: :unprocessable_entity
      end

      private

      def ai_discover_persona
        @discover_persona ||= AiPersona.find_by_id_from_cache(SiteSetting.ai_discover_persona)
      end

      def check_permissions
        if ai_discover_persona.nil? || current_user.nil? ||
             !current_user.in_any_groups?(ai_discover_persona.allowed_group_ids.to_a)
          raise Discourse::InvalidAccess.new
        end
      end
    end
  end
end
