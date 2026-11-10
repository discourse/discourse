# frozen_string_literal: true

module DiscourseAi
  module Summarization
    class PublishedSummary
      def initialize(topic_view, guardian:, crawler_only: true)
        @topic_view = topic_view
        @guardian = guardian
        @crawler_only = crawler_only
      end

      def eligible?
        return false if @crawler_only && !crawler_request?

        topic = @topic_view.topic
        SiteSetting.ai_summaries_for_crawlers && SiteSetting.ai_summarization_enabled &&
          !SiteSetting.login_required && @topic_view.page == 1 &&
          !@topic_view.single_post_request? && topic.regular? && topic.visible &&
          !topic.category&.read_restricted && Guardian.new.can_see?(topic)
      end

      def summary
        return @summary if defined?(@summary)

        @summary = nil
        return unless eligible?

        cached_summary =
          DiscourseAi::TopicSummarization.for(
            @topic_view.topic,
            nil,
            scope: @guardian,
          ).cached_summary
        if cached_summary&.summarized_text.present? &&
             Guardian.new.can_see_summary?(@topic_view.topic, cached_summary:)
          @summary = cached_summary
        end
        @summary
      end

      def cooked
        summary.summarized_cooked
      end

      def markdown
        heading = I18n.t("discourse_ai.summarization.published_summary_heading")
        "## #{heading}\n\n#{summary.summarized_text}"
      end

      private

      def crawler_request?
        request = @guardian.request
        request.present? && Middleware::AnonymousCache::Helper.new(request.env).is_crawler?
      end
    end
  end
end
