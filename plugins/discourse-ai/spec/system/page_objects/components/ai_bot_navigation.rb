# frozen_string_literal: true

module PageObjects
  module Components
    class AiBotNavigation < Base
      def has_shortcuts?
        page.has_css?(".sidebar-section-link[data-link-name='ai-bot']") &&
          page.has_css?("header .ai-bot-button")
      end

      def has_no_shortcuts?
        page.has_no_css?(".sidebar-section-link[data-link-name='ai-bot']") &&
          page.has_no_css?("header .ai-bot-button")
      end
    end
  end
end
