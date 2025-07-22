# frozen_string_literal: true

module DiscourseAi
  module Sentiment
    class EntryPoint
      def inject_into(plugin)
        sentiment_analysis_cb =
          Proc.new do |post|
            if SiteSetting.ai_sentiment_enabled
              Jobs.enqueue(:post_sentiment_analysis, post_id: post.id)
            end
          end

        plugin.on(:post_edited, &sentiment_analysis_cb)

        plugin.add_to_serializer(:current_user, :can_see_sentiment_reports) do
          ClassificationResult.has_sentiment_classification? && SiteSetting.ai_sentiment_enabled
        end

        # TODO we need new interfaces to conditionally register depending on site in the multisite
        EmotionFilterOrder.register!(plugin)
        EmotionDashboardReport.register!(plugin)
        SentimentDashboardReport.register!(plugin)
        SentimentAnalysisReport.register!(plugin)
      end
    end
  end
end
