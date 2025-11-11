# frozen_string_literal: true

module PageObjects
  module Components
    class AiSummaryTrigger < PageObjects::Components::Base
      SUMMARY_BUTTON_SELECTOR = ".ai-summarization-button"
      SUMMARY_CONTAINER_SELECTOR = ".ai-summary-modal"

      def click_summarize
        find(SUMMARY_BUTTON_SELECTOR).click
      end

      def click_regenerate_summary
        find("#{SUMMARY_CONTAINER_SELECTOR} .d-modal__footer button").click
      end

      def has_summary?(summary)
        find("#{SUMMARY_CONTAINER_SELECTOR} .generated-summary p").text == summary
      end

      def has_generating_summary_indicator?
        find("#{SUMMARY_CONTAINER_SELECTOR} .ai-summary__generating-text").present?
      end
    end
  end
end
