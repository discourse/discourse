# frozen_string_literal: true

module PageObjects
  module Modals
    class ContentLanguagePreferences < PageObjects::Modals::Base
      MODAL_SELECTOR = ".content-language-preferences-modal"

      def initialize
        super(body_selector: "", modal_selector: MODAL_SELECTOR)
      end

      def has_understood_languages_login_prompt?
        body.has_css?(
          ".content-language-preferences-modal__understood",
          text: "Languages I understand Log in to set more languages",
        ) && body.has_no_css?(".form-kit__field[data-name='understoodLanguages']", wait: 0)
      end

      def has_logged_in_language_controls?
        body.has_css?(".form-kit__field[data-name='interfaceLanguage'] select") &&
          body.has_css?(".form-kit__field[data-name='understoodLanguages'] .multi-select") &&
          body.has_no_css?(".content-language-preferences-modal__understood")
      end

      def has_read_only_interface_language?(language)
        body.has_css?(".form-kit__field[data-name='interfaceLanguage'] select:disabled") &&
          body.has_css?(
            ".form-kit__field[data-name='interfaceLanguage'] option:checked",
            text: language,
          )
      end

      def has_understood_languages_description?
        body.has_css?(
          ".form-kit__field[data-name='understoodLanguages'] " \
            ".form-kit__container-description",
          text:
            "Topics and posts in these languages won’t be translated. " \
              "Your interface language is always included.",
        )
      end

      def has_locked_understood_language?
        understood_languages_dropdown.expand
        result =
          body.has_css?(
            ".form-kit__field[data-name='understoodLanguages'] " \
              ".selected-content .tag-choice.disabled",
            count: 1,
          )
        understood_languages_dropdown.collapse
        result
      end

      def automatic_translation_enabled?
        body.has_css?("[data-test-automatically-translate]:checked", visible: :all)
      end

      def disable_automatic_translation
        body.find(".form-kit__field-checkbox label").click
        self
      end

      def save
        click_primary_button
        self
      end

      private

      def understood_languages_dropdown
        PageObjects::Components::SelectKit.new(
          ".form-kit__field[data-name='understoodLanguages'] .multi-select",
        )
      end
    end
  end
end
