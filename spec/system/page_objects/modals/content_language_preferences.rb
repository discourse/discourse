# frozen_string_literal: true

module PageObjects
  module Modals
    class ContentLanguagePreferences < PageObjects::Modals::Base
      MODAL_SELECTOR = ".content-language-preferences-modal"

      def initialize
        super(body_selector: "", modal_selector: MODAL_SELECTOR)
      end

      def has_understood_languages_login_prompt?
        have_count(0).does_not_match?(
          browser_root.locator(
            "#{full_modal_selector} " \
              ".content-language-preferences-modal__understood a[href='/login']",
          ).filter(visible: true),
        )
      end

      def has_logged_in_language_controls?
        have_count(0).does_not_match?(
          body.locator(".form-kit__field[data-name='interfaceLanguage'] select").filter(
            visible: true,
          ),
        ) &&
          have_count(0).does_not_match?(
            body.locator(".form-kit__field[data-name='understoodLanguages'] .multi-select").filter(
              visible: true,
            ),
          ) &&
          have_count(0).matches?(
            body
              .tap do |parent|
                parent.wait_for(state: "visible", timeout: Capybara.default_max_wait_time * 1000)
              end
              .locator(".content-language-preferences-modal__understood")
              .filter(visible: true),
          )
      end

      def has_read_only_interface_language?(language)
        have_count(0).does_not_match?(
          body.locator(".form-kit__field[data-name='interfaceLanguage'] select:disabled").filter(
            visible: true,
          ),
        ) &&
          contain_text([browser_text_pattern(language)], useInnerText: true).matches?(
            body.locator(".form-kit__field[data-name='interfaceLanguage'] option:checked"),
          )
      end

      def has_understood_language_option?(locale)
        understood_languages_dropdown.expand
        result =
          have_count(0).does_not_match?(
            browser_root.locator(
              "#{full_modal_selector} " \
                ".form-kit__field[data-name='understoodLanguages'] " \
                ".select-kit-row[data-value='#{locale}']",
            ).filter(visible: true),
          )
        understood_languages_dropdown.collapse
        result
      end

      def has_removable_understood_language?(locale)
        understood_languages_dropdown.expand
        result =
          have_count(0).does_not_match?(
            body.locator(
              ".form-kit__field[data-name='understoodLanguages'] " \
                "button.selected-choice[data-value='#{locale}']:not(:disabled)",
            ).filter(visible: true),
          )
        understood_languages_dropdown.collapse
        result
      end

      def remove_understood_language(locale)
        understood_languages_dropdown.expand
        body
          .locator(
            ".form-kit__field[data-name='understoodLanguages'] " \
              "button.selected-choice[data-value='#{locale}']",
          )
          .filter(visible: true)
          .click
        understood_languages_dropdown.collapse
        self
      end

      def automatic_translation_enabled?
        have_count(0).does_not_match?(body.locator("[data-test-automatically-translate]:checked"))
      end

      def disable_automatic_translation
        body.locator(".form-kit__field-checkbox label").filter(visible: true).click
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
