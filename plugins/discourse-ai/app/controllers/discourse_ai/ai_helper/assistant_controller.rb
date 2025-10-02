# frozen_string_literal: true

module DiscourseAi
  module AiHelper
    class AssistantController < ::ApplicationController
      requires_plugin PLUGIN_NAME
      requires_login
      before_action :ensure_can_request_suggestions
      before_action :rate_limiter_performed!

      include SecureUploadEndpointHelpers

      RATE_LIMITS = {
        "default" => {
          amount: 6,
          interval: 3.minutes,
        },
        "caption_image" => {
          amount: 20,
          interval: 1.minute,
        },
      }.freeze

      def suggest
        input = get_text_param!
        force_default_locale = params[:force_default_locale] || false

        raise Discourse::InvalidParameters.new(:mode) if params[:mode].blank?

        if params[:mode] == DiscourseAi::AiHelper::Assistant::CUSTOM_PROMPT
          raise Discourse::InvalidParameters.new(:custom_prompt) if params[:custom_prompt].blank?
        end

        if params[:mode] == DiscourseAi::AiHelper::Assistant::ILLUSTRATE_POST
          return suggest_thumbnails(input)
        end

        hijack do
          render json:
                   DiscourseAi::AiHelper::Assistant.new.generate_and_send_prompt(
                     params[:mode],
                     input,
                     current_user,
                     force_default_locale: force_default_locale,
                     custom_prompt: params[:custom_prompt],
                   ),
                 status: 200
        end
      rescue DiscourseAi::Completions::Endpoints::Base::CompletionFailed
        render_json_error I18n.t("discourse_ai.ai_helper.errors.completion_request_failed"),
                          status: 502
      end

      def suggest_title
        if params[:topic_id]
          topic = Topic.find_by(id: params[:topic_id])
          guardian.ensure_can_see!(topic)
          input = DiscourseAi::Summarization::Strategies::TopicSummary.new(topic).targets_data
        else
          input = get_text_param!
        end

        hijack do
          render json:
                   DiscourseAi::AiHelper::Assistant.new.generate_and_send_prompt(
                     DiscourseAi::AiHelper::Assistant::GENERATE_TITLES,
                     input,
                     current_user,
                   ),
                 status: 200
        end
      rescue DiscourseAi::Completions::Endpoints::Base::CompletionFailed
        render_json_error I18n.t("discourse_ai.ai_helper.errors.completion_request_failed"),
                          status: 502
      end

      def suggest_category
        if params[:topic_id]
          topic = Topic.find_by(id: params[:topic_id])
          guardian.ensure_can_see!(topic)
          opts = { topic_id: topic.id }
        else
          input = get_text_param!
          opts = { text: input }
        end

        render json: DiscourseAi::AiHelper::SemanticCategorizer.new(current_user, opts).categories,
               status: 200
      end

      def suggest_tags
        if params[:topic_id]
          topic = Topic.find_by(id: params[:topic_id])
          guardian.ensure_can_see!(topic)
          opts = { topic_id: topic.id }
        else
          input = get_text_param!
          opts = { text: input }
        end

        render json: DiscourseAi::AiHelper::SemanticCategorizer.new(current_user, opts).tags,
               status: 200
      end

      def suggest_thumbnails(input)
        hijack do
          thumbnails = DiscourseAi::AiHelper::Painter.new.commission_thumbnails(input, current_user)

          render json: { thumbnails: thumbnails }, status: 200
        end
      end

      def stream_suggestion
        text = get_text_param!

        location = params[:location]
        raise Discourse::InvalidParameters.new(:location) if !location

        raise Discourse::InvalidParameters.new(:mode) if params[:mode].blank?
        if params[:mode] == DiscourseAi::AiHelper::Assistant::ILLUSTRATE_POST
          return suggest_thumbnails(input)
        end

        if params[:mode] == DiscourseAi::AiHelper::Assistant::CUSTOM_PROMPT
          raise Discourse::InvalidParameters.new(:custom_prompt) if params[:custom_prompt].blank?
        end

        # to stream we must have an appropriate client_id
        # otherwise we may end up streaming the data to the wrong client
        raise Discourse::InvalidParameters.new(:client_id) if params[:client_id].blank?

        channel_id = next_channel_id
        progress_channel = "discourse_ai_helper/stream_suggestions/#{channel_id}"

        if location == "composer"
          Jobs.enqueue(
            :stream_composer_helper,
            user_id: current_user.id,
            text: text,
            prompt: params[:mode],
            custom_prompt: params[:custom_prompt],
            force_default_locale: params[:force_default_locale] || false,
            client_id: params[:client_id],
            progress_channel:,
          )
        else
          post_id = get_post_param!
          post = Post.includes(:topic).find_by(id: post_id)

          raise Discourse::InvalidParameters.new(:post_id) unless post

          Jobs.enqueue(
            :stream_post_helper,
            post_id: post.id,
            user_id: current_user.id,
            text: text,
            prompt: params[:mode],
            custom_prompt: params[:custom_prompt],
            client_id: params[:client_id],
            progress_channel:,
          )
        end

        render json: { success: true, progress_channel: }, status: 200
      rescue DiscourseAi::Completions::Endpoints::Base::CompletionFailed
        render_json_error I18n.t("discourse_ai.ai_helper.errors.completion_request_failed"),
                          status: 502
      end

      def caption_image
        image_url = params[:image_url]
        image_url_type = params[:image_url_type]

        raise Discourse::InvalidParameters.new(:image_url) if !image_url
        raise Discourse::InvalidParameters.new(:image_url) if !image_url_type

        if image_url_type == "short_path"
          image = Upload.find_by(sha1: Upload.sha1_from_short_path(image_url))
        elsif image_url_type == "short_url"
          image = Upload.find_by(sha1: Upload.sha1_from_short_url(image_url))
        else
          image = upload_from_full_url(image_url)
        end

        raise Discourse::NotFound if image.blank?

        check_secure_upload_permission(image) if image.secure?
        user = current_user

        hijack do
          caption = DiscourseAi::AiHelper::Assistant.new.generate_image_caption(image, user)
          render json: {
                   caption:
                     "#{caption} (#{I18n.t("discourse_ai.ai_helper.image_caption.attribution")})",
                 },
                 status: 200
        end
      rescue DiscourseAi::Completions::Endpoints::Base::CompletionFailed, Net::HTTPBadResponse
        render_json_error I18n.t("discourse_ai.ai_helper.errors.completion_request_failed"),
                          status: 502
      end

      private

      CHANNEL_ID_KEY = "discourse_ai_helper_next_channel_id"

      def next_channel_id
        Discourse
          .redis
          .pipelined do |pipeline|
            pipeline.incr(CHANNEL_ID_KEY)
            pipeline.expire(CHANNEL_ID_KEY, 1.day)
          end
          .first
      end

      def get_text_param!
        params[:text].tap { |t| raise Discourse::InvalidParameters.new(:text) if t.blank? }
      end

      def get_post_param!
        params[:post_id].tap { |t| raise Discourse::InvalidParameters.new(:post_id) if t.blank? }
      end

      def rate_limiter_performed!
        action_rate_limit = RATE_LIMITS[action_name] || RATE_LIMITS["default"]
        RateLimiter.new(
          current_user,
          "ai_assistant",
          action_rate_limit[:amount],
          action_rate_limit[:interval],
        ).performed!
      end

      def ensure_can_request_suggestions
        allowed_groups =
          (
            SiteSetting.composer_ai_helper_allowed_groups_map |
              SiteSetting.post_ai_helper_allowed_groups_map
          )

        raise Discourse::InvalidAccess if !current_user.in_any_groups?(allowed_groups)
      end
    end
  end
end
