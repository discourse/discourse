# frozen_string_literal: true

module DiscourseAi
  module Summarization
    class SummaryController < ::ApplicationController
      include AiCreditLimitHandler

      requires_plugin PLUGIN_NAME

      def show
        topic = Topic.find(params[:topic_id])
        guardian.ensure_can_see!(topic)
        summarization_service = DiscourseAi::TopicSummarization.for(topic, current_user)
        cached_summary = summarization_service.cached_summary

        if !guardian.can_see_summary?(topic, cached_summary: cached_summary)
          raise Discourse::NotFound
        end

        RateLimiter.new(current_user, "summary", 6, 5.minutes).performed! if current_user

        opts = params.permit(:skip_age_check)
        skip_age_check = opts[:skip_age_check] == "true"

        if params[:stream] && current_user
          if cached_summary && !skip_age_check
            render_serialized(cached_summary, AiTopicSummarySerializer)
            return
          end

          Jobs.enqueue(
            :stream_topic_ai_summary,
            topic_id: topic.id,
            user_id: current_user.id,
            skip_age_check: skip_age_check,
          )

          render json: success_json
        else
          hijack do
            summary = summarization_service.summarize(skip_age_check: skip_age_check)
            raise Discourse::NotFound if summary.nil?

            render_serialized(summary, AiTopicSummarySerializer)
          end
        end
      end

      def regen_gist
        RegenerateSummaries.call(**service_params, params: params.merge(type: "gist")) do
          on_success { render json: success_json }
          on_failed_policy(:can_regenerate) { raise Discourse::InvalidAccess }
          on_failed_contract do |contract|
            raise Discourse::InvalidParameters, contract.errors.full_messages.join(", ")
          end
        end
      end

      def regen_summary
        RegenerateSummaries.call(**service_params, params: params.merge(type: "summary")) do
          on_success { render json: success_json }
          on_failed_policy(:can_regenerate) { raise Discourse::InvalidAccess }
          on_failed_contract do |contract|
            raise Discourse::InvalidParameters, contract.errors.full_messages.join(", ")
          end
        end
      end
    end
  end
end
