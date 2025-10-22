# frozen_string_literal: true

module PageObjects
  module Components
    class AiSuggestionDropdown < PageObjects::Components::Base
      SUGGESTION_BUTTON_SELECTOR = ".suggestion-button"
      TITLE_BUTTON_SELECTOR = "#{SUGGESTION_BUTTON_SELECTOR}.suggest-titles-button"
      CATEGORY_BUTTON_SELECTOR = "#{SUGGESTION_BUTTON_SELECTOR}.suggest-category-button"
      TAG_BUTTON_SELECTOR = "#{SUGGESTION_BUTTON_SELECTOR}.suggest-tags-button"
      MENU_SELECTOR = ".ai-suggestions-menu"

      def click_suggest_titles_button
        page.find(TITLE_BUTTON_SELECTOR, visible: :all).click
      end

      def click_suggest_category_button
        find(CATEGORY_BUTTON_SELECTOR, visible: :all).click
      end

      def click_suggest_tags_button
        find(TAG_BUTTON_SELECTOR, visible: :all).click
      end

      def select_suggestion_by_value(index)
        find("#{MENU_SELECTOR} button[data-value=\"#{index}\"]").click
      end

      def select_suggestion_by_name(name)
        find("#{MENU_SELECTOR} button[data-name=\"#{name}\"]").click
      end

      def suggestion_name(index)
        suggestion = find("#{MENU_SELECTOR} button[data-value=\"#{index}\"]")
        suggestion["data-name"]
      end

      def has_dropdown?
        has_css?(MENU_SELECTOR)
      end

      def has_no_dropdown?
        has_no_css?(MENU_SELECTOR)
      end

      def has_suggestion_button?
        has_css?(SUGGESTION_BUTTON_SELECTOR)
      end

      def has_no_suggestion_button?
        has_no_css?(SUGGESTION_BUTTON_SELECTOR)
      end
    end
  end
end
