# frozen_string_literal: true

module DiscourseAi
  module AiBot
    class SharedAiConversationsController < ::ApplicationController
      requires_plugin ::DiscourseAi::PLUGIN_NAME
      requires_login only: %i[create update destroy]
      before_action :require_site_settings!

      skip_before_action :preload_json, :check_xhr, only: %i[show asset]
      skip_before_action :redirect_to_login_if_required, :verify_authenticity_token, only: %i[asset]

      def create
        ensure_allowed_create!

        RateLimiter.new(current_user, "share-ai-conversation", 10, 1.minute).performed!

        shared_conversation = SharedAiConversation.share_conversation(current_user, @topic)

        if shared_conversation.persisted?
          render json: success_json.merge(share_key: shared_conversation.share_key)
        else
          render json:
                   failed_json.merge(error: I18n.t("discourse_ai.share_ai.errors.failed_to_share")),
                 status: :unprocessable_entity
        end
      end

      def destroy
        ensure_allowed_destroy!

        SharedAiConversation.destroy_conversation(@shared_conversation)

        render json:
                 success_json.merge(
                   message: I18n.t("discourse_ai.share_ai.errors.conversation_deleted"),
                 )
      end

      def show
        @shared_conversation = SharedAiConversation.find_by(share_key: params[:share_key])
        raise Discourse::NotFound if @shared_conversation.blank?

        expires_in 1.minute, public: true
        response.headers["X-Robots-Tag"] = "noindex"

        if request.format.json?
          render json: success_json.merge(@shared_conversation.to_json)
        else
          render "show", layout: false
        end
      end

      def asset
        no_cookies

        name = params[:name]
        path, content_type =
          if name == "share"
            %w[share.css text/css]
          elsif name == "highlight"
            %w[highlight.min.js application/javascript]
          else
            raise Discourse::NotFound
          end

        content = File.read(DiscourseAi.public_asset_path("ai-share/#{path}"))

        # note, path contains a ":version" which automatically busts the cache
        # based on file content, so this is safe
        response.headers["Last-Modified"] = 10.years.ago.httpdate
        response.headers["Content-Length"] = content.bytesize.to_s
        immutable_for 1.year

        render plain: content, disposition: :nil, content_type: content_type
      end

      def preview
        ensure_allowed_preview!
        data = SharedAiConversation.build_conversation_data(@topic, include_usernames: true)
        data[:error] = @error if @error
        data[:share_key] = @shared_conversation.share_key if @shared_conversation
        data[:topic_id] = @topic.id
        render json: data
      end

      private

      def require_site_settings!
        if !SiteSetting.discourse_ai_enabled ||
             !SiteSetting.ai_bot_public_sharing_allowed_groups_map.any? ||
             !SiteSetting.ai_bot_enabled
          raise Discourse::NotFound
        end
      end

      def ensure_allowed_preview!
        @topic = Topic.find_by(id: params[:topic_id])
        raise Discourse::NotFound if !@topic

        @shared_conversation = SharedAiConversation.find_by(target: @topic)

        @error = DiscourseAi::AiBot::EntryPoint.ai_share_error(@topic, guardian)
        if @error == :not_allowed
          raise Discourse::InvalidAccess.new(
                  nil,
                  nil,
                  custom_message: "discourse_ai.share_ai.errors.#{@error}",
                )
        end
      end

      def ensure_allowed_destroy!
        @shared_conversation = SharedAiConversation.find_by(share_key: params[:share_key])

        raise Discourse::InvalidAccess if @shared_conversation.blank?

        guardian.ensure_can_destroy_shared_ai_bot_conversation!(@shared_conversation)
      end

      def ensure_allowed_create!
        @topic = Topic.find_by(id: params[:topic_id])
        raise Discourse::NotFound if !@topic

        error = DiscourseAi::AiBot::EntryPoint.ai_share_error(@topic, guardian)
        if error
          raise Discourse::InvalidAccess.new(
                  nil,
                  nil,
                  custom_message: "discourse_ai.share_ai.errors.#{error}",
                )
        end
      end
    end
  end
end
