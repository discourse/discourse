# frozen_string_literal: true

module DiscourseAi
  module Summarization
    class SummaryController < ::ApplicationController
      requires_plugin PLUGIN_NAME

      def show
        topic = Topic.find(params[:topic_id])
        guardian.ensure_can_see!(topic)

        raise Discourse::NotFound if !guardian.can_see_summary?(topic)

        RateLimiter.new(current_user, "summary", 6, 5.minutes).performed! if current_user

        opts = params.permit(:skip_age_check)
        skip_age_check = opts[:skip_age_check] == "true"

        summarization_service = DiscourseAi::TopicSummarization.for(topic, current_user)

        if params[:stream] && current_user
          cached_summary = summarization_service.cached_summary

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
            render_serialized(summary, AiTopicSummarySerializer)
          end
        end
      end

      def regen_gist
        raise Discourse::InvalidAccess if !guardian.can_request_gists?

        topics = []

        if params[:topic_ids].present?
          topic_ids =
            params[:topic_ids].is_a?(String) ? params[:topic_ids].split(",") : params[:topic_ids]
          topics = Topic.where(id: topic_ids)
        elsif params[:topic_id].present?
          topics = [Topic.find(params[:topic_id])]
        else
          raise Discourse::InvalidParameters.new(:topic_id)
        end

        if current_user && topics.size >= 1
          RateLimiter.new(current_user, "summary", 6, 5.minutes).performed!
        end

        if topics.size > TopicQuery::DEFAULT_PER_PAGE_COUNT
          raise Discourse::InvalidParameters.new(:topic_ids)
        end

        topics.each do |topic|
          guardian.ensure_can_see!(topic)

          summarizer = DiscourseAi::Summarization.topic_gist(topic)
          summarizer.delete_cached_summaries! if summarizer.present?

          Jobs.enqueue(:fast_track_topic_gist, topic_id: topic.id, force_regenerate: true)
        end

        render json: success_json
      end
    end
  end
end
