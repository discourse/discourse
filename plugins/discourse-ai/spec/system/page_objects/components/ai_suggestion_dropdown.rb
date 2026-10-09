# frozen_string_literal: true

module PageObjects
  module Components
    class AiSuggestionDropdown < PageObjects::Components::Base
      MENU_SELECTOR = ".ai-suggestions-menu"

      def select_suggestion_by_value(index)
        find("#{MENU_SELECTOR} button[data-value=\"#{index}\"]").click
      end

      def has_dropdown?
        has_css?(MENU_SELECTOR)
      end

      def has_no_dropdown?
        has_no_css?(MENU_SELECTOR)
      end
    end
  end
end
