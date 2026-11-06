# frozen_string_literal: true

module PageObjects
  module Components
    class AiDsaClassificationSuggestion < PageObjects::Components::Base
      SELECTOR = ".ai-dsa-classification-suggestion"

      def suggest
        find("#{SELECTOR}__button").click
        self
      end

      def has_message?(text)
        has_css?("#{SELECTOR}__message", text:)
      end
    end
  end
end
