# frozen_string_literal: true

module PageObjects
  module Components
    class AiPostHelperMenu < PageObjects::Components::Base
      POST_SELECTION_TOOLBAR_SELECTOR = ".quote-button"
      QUOTE_SELECTOR = ".insert-quote"
      EDIT_SELECTOR = ".quote-edit-label"
      SHARE_SELECTOR = ".quote-sharing"

      AI_HELPER_SELECTOR = ".ai-post-helper"
      TRIGGER_SELECTOR = "#{AI_HELPER_SELECTOR}__trigger"
      OPTIONS_SELECTOR = ".ai-helper-options"
      LOADING_SELECTOR = ".ai-helper-context-menu__loading"
      SUGGESTION_SELECTOR = "#{AI_HELPER_SELECTOR}__suggestion"
      HIGHLIGHT_SELECTOR = ".ai-helper-highlighted-selection"

      def click_ai_button
        find(TRIGGER_SELECTOR).click
      end

      def click_add_footnote
        find("#{SUGGESTION_SELECTOR}__insert-footnote").click
      end

      def select_helper_model(mode)
        find("#{OPTIONS_SELECTOR} .btn[data-name=\"#{mode}\"]").click
      end

      def has_suggestion_value?(value)
        page.has_css?("#{SUGGESTION_SELECTOR}__text", text: value)
      end

      def suggestion_value
        find("#{SUGGESTION_SELECTOR}__text").text
      end

      def has_highlighted_text?
        page.has_css?(HIGHLIGHT_SELECTOR)
      end

      def has_no_highlighted_text?
        page.has_no_css?(HIGHLIGHT_SELECTOR)
      end

      def has_mobile_post_ai_helper?
        page.has_css?(".fk-d-menu-modal #{AI_HELPER_SELECTOR}")
      end

      def has_no_mobile_post_ai_helper?
        page.has_no_css?(".fk-d-menu-modal #{AI_HELPER_SELECTOR}")
      end

      def has_post_ai_helper?
        page.has_css?(AI_HELPER_SELECTOR)
      end

      def has_no_post_ai_helper?
        page.has_no_css?(AI_HELPER_SELECTOR)
      end

      def has_post_ai_helper_options?
        page.has_css?(OPTIONS_SELECTOR)
      end

      def has_no_post_ai_helper_options?
        page.has_no_css?(OPTIONS_SELECTOR)
      end

      def has_post_selection_toolbar?
        page.has_css?(POST_SELECTION_TOOLBAR_SELECTOR)
      end

      def has_no_post_selection_toolbar?
        page.has_no_css?(POST_SELECTION_TOOLBAR_SELECTOR)
      end

      def has_post_selection_primary_buttons?
        page.has_css?(QUOTE_SELECTOR) || page.has_css?(EDIT_SELECTOR) ||
          page.has_css?(SHARE_SELECTOR)
      end

      def has_no_post_selection_primary_buttons?
        page.has_no_css?(QUOTE_SELECTOR) || page.has_no_css?(EDIT_SELECTOR) ||
          page.has_no_css?(SHARE_SELECTOR)
      end

      def has_suggestions?
        page.has_css?(SUGGESTION_SELECTOR)
      end
    end
  end
end
