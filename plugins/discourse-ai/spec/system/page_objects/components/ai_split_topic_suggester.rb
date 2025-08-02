# frozen_string_literal: true

module PageObjects
  module Components
    class AiSplitTopicSuggester < PageObjects::Components::Base
      SUGGESTION_BUTTON_SELECTOR = ".ai-split-topic-suggestion-button"
      TITLE_BUTTON_SELECTOR = "#{SUGGESTION_BUTTON_SELECTOR}[data-suggestion-mode='suggest_title']"
      CATEGORY_BUTTON_SELECTOR =
        "#{SUGGESTION_BUTTON_SELECTOR}[data-suggestion-mode='suggest_category']"
      TAG_BUTTON_SELECTOR = "#{SUGGESTION_BUTTON_SELECTOR}[data-suggestion-mode='suggest_tags']"
      MENU_SELECTOR = ".fk-d-menu[data-identifier='ai-split-topic-suggestion-menu']"

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
        find("#{MENU_SELECTOR} li[data-value=\"#{index}\"]").click
      end

      def select_suggestion_by_name(name)
        find("#{MENU_SELECTOR} li[data-name=\"#{name}\"]").click
      end

      def suggestion_name(index)
        suggestion = find("#{MENU_SELECTOR} li[data-value=\"#{index}\"]")
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
