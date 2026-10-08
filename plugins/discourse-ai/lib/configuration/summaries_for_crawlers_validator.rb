# frozen_string_literal: true

module DiscourseAi
  module Configuration
    class SummariesForCrawlersValidator
      def initialize(opts = {})
        @opts = opts
      end

      def valid_value?(val)
        return true if val == false || val == "f" || val == "false"

        SiteSetting.ai_summary_backfill_maximum_topics_per_hour > 0
      end

      def error_message
        I18n.t("discourse_ai.summarization.configuration.backfill_required")
      end
    end
  end
end
