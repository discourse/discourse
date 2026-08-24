# frozen_string_literal: true

module DiscourseAi
  module Discover
    class DiscoveriesController < ::ApplicationController
      include AiCreditLimitHandler

      MAX_QUERY_LENGTH = 1000

      requires_plugin PLUGIN_NAME
      requires_login
      before_action :check_permissions!

      def reply
        query = normalized_query
        request_id = params[:request_id].to_s
        if !DiscourseAi::Discoveries.valid_request_id?(request_id)
          render_json_error(
            I18n.t("discourse_ai.ai_bot.discoveries.errors.invalid_request_id"),
            status: :bad_request,
          )
          return
        end

        RateLimiter.new(current_user, "ai_discover_#{current_user.id}", 8, 1.minute).performed!

        binding =
          DiscourseAi::Discoveries.bind_request(user_id: current_user.id, request_id:, query:)
        if binding == :created
          result_settings = DiscourseAi::Discoveries.result_settings
          Jobs.enqueue(
            :stream_discover_reply,
            user_id: current_user.id,
            query:,
            request_id:,
            queued_at: Time.now.to_f,
            summary_detail: result_settings[:summary_detail].to_s,
            related_count: result_settings[:related_count],
          )
        end

        render json: { request_id: }, status: :ok
      rescue DiscourseAi::Discoveries::RequestConflict
        render_json_error(
          I18n.t("discourse_ai.ai_bot.discoveries.errors.request_conflict"),
          status: :conflict,
        )
      end

      def continue_convo
        topic_id =
          DiscourseAi::Discoveries::ContinueConversation.new(
            user: current_user,
            discovery_agent: ai_discover_agent,
            follow_up_agent: ai_discover_follow_up_agent,
          ).call(request_id: params[:request_id].to_s, question: params[:question])

        render json: success_json.merge(topic_id:)
      rescue DiscourseAi::Discoveries::ContinueConversation::ResultExpired
        render_json_error(
          I18n.t("discourse_ai.ai_bot.discoveries.errors.result_expired"),
          status: :not_found,
        )
      rescue Discourse::InvalidAccess, Discourse::InvalidParameters
        raise
      rescue StandardError => e
        Rails.logger.error("Discourse AI Discoveries follow-up failed: #{e.class}")
        render_json_error(
          I18n.t("discourse_ai.ai_bot.discoveries.errors.follow_up_failed"),
          status: :unprocessable_entity,
        )
      end

      private

      def ai_discover_agent
        @discover_agent ||= AiAgent.find_by_id_from_cache(SiteSetting.ai_discover_agent)
      end

      def ai_discover_follow_up_agent
        @discover_follow_up_agent ||=
          AiAgent.find_by_id_from_cache(SiteSetting.ai_discover_follow_up_agent)
      end

      def check_permissions!
        raise Discourse::InvalidAccess if !DiscourseAi::Discoveries.enabled_for_user?(current_user)
      end

      def normalized_query
        query = params[:query].to_s.strip
        if query.blank? || query.length > MAX_QUERY_LENGTH || query.include?("\0")
          raise Discourse::InvalidParameters.new(
                  I18n.t(
                    "discourse_ai.ai_bot.discoveries.errors.invalid_query",
                    max: MAX_QUERY_LENGTH,
                  ),
                )
        end

        query
      end
    end
  end
end
