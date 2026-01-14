# frozen_string_literal: true

module PageObjects
  module Components
    class AiComposerHelperMenu < PageObjects::Components::Base
      COMPOSER_EDITOR_SELECTOR = ".d-editor-input"
      CONTEXT_MENU_SELECTOR = ".ai-composer-helper-menu"
      OPTIONS_STATE_SELECTOR = ".ai-helper-options"
      LOADING_STATE_SELECTOR = ".ai-helper-loading"
      CUSTOM_PROMPT_SELECTOR = "#{CONTEXT_MENU_SELECTOR} .ai-custom-prompt"
      CUSTOM_PROMPT_INPUT_SELECTOR = "#{CUSTOM_PROMPT_SELECTOR}__input"
      CUSTOM_PROMPT_BUTTON_SELECTOR = "#{CUSTOM_PROMPT_SELECTOR}__submit"

      def select_helper_model(mode)
        find(
          "#{OPTIONS_STATE_SELECTOR} li[data-value=\"#{mode}\"] .ai-helper-options__button",
        ).click
      end

      def press_undo_keys
        find(COMPOSER_EDITOR_SELECTOR).send_keys([PLATFORM_KEY_MODIFIER, "z"])
      end

      def press_escape_key
        find("body").send_keys(:escape)
      end

      def click_custom_prompt_button
        find(CUSTOM_PROMPT_BUTTON_SELECTOR).click
      end

      def fill_custom_prompt(content)
        find(CUSTOM_PROMPT_INPUT_SELECTOR).fill_in(with: content)
        self
      end

      def has_context_menu?
        page.has_css?(CONTEXT_MENU_SELECTOR)
      end

      def has_no_context_menu?
        page.has_no_css?(CONTEXT_MENU_SELECTOR)
      end

      def showing_options?
        page.has_css?(OPTIONS_STATE_SELECTOR)
      end

      def showing_loading?
        page.has_css?(LOADING_STATE_SELECTOR)
      end

      def has_custom_prompt?
        page.has_css?(CUSTOM_PROMPT_SELECTOR)
      end

      def has_no_custom_prompt?
        page.has_no_css?(CUSTOM_PROMPT_SELECTOR)
      end

      def has_custom_prompt_button?
        page.has_css?(CUSTOM_PROMPT_BUTTON_SELECTOR)
      end

      def has_no_custom_prompt_button?
        page.has_no_css?(CUSTOM_PROMPT_BUTTON_SELECTOR)
      end

      def has_custom_prompt_button_enabled?
        page.has_css?("#{CUSTOM_PROMPT_BUTTON_SELECTOR}:not(:disabled)")
      end

      def has_custom_prompt_button_disabled?
        page.has_css?("#{CUSTOM_PROMPT_BUTTON_SELECTOR}:disabled")
      end
    end
  end
end
