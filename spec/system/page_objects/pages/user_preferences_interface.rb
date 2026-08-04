# frozen_string_literal: true

module PageObjects
  module Pages
    class UserPreferencesInterface < PageObjects::Pages::Base
      AUTOMATIC_TRANSLATION_SELECTOR =
        "[data-setting-name='user-content-languages'] " \
          "[data-setting-name='user-automatically-translate'] input"

      def visit(user)
        page.visit("/u/#{user.username}/preferences/interface")
        self
      end

      def has_bookmark_after_notification_mode?(value)
        page.has_css?(
          "#bookmark-after-notification-mode .select-kit-header[data-value=\"#{value}\"]",
        )
      end

      def select_bookmark_after_notification_mode(value)
        page.find("#bookmark-after-notification-mode").click
        page.find(".select-kit-row[data-value=\"#{value}\"]").click
        self
      end

      def theme_dropdown
        PageObjects::Components::SelectKit.new("[data-setting-name='user-theme'] .combo-box")
      end

      def text_size_dropdown
        PageObjects::Components::SelectKit.new("[data-setting-name='user-text-size'] .combo-box")
      end

      def has_interface_language_section?
        page.has_css?("[data-setting-name='user-locale'] .control-label")
      end

      def has_no_interface_language_section?
        page.has_no_css?("[data-setting-name='user-locale'] .control-label")
      end

      def has_content_languages_section?
        page.has_css?("[data-setting-name='user-content-languages'] .control-label")
      end

      def automatic_translation_enabled?
        page.has_css?("#{AUTOMATIC_TRANSLATION_SELECTOR}:checked")
      end

      def automatic_translation_disabled?
        page.has_no_css?("#{AUTOMATIC_TRANSLATION_SELECTOR}:checked")
      end

      def disable_automatic_translation
        page.find("#{AUTOMATIC_TRANSLATION_SELECTOR}:checked").click
        self
      end

      def enable_automatic_translation
        page.find("#{AUTOMATIC_TRANSLATION_SELECTOR}:not(:checked)").click
        self
      end

      def has_removable_understood_language?(locale)
        understood_languages_dropdown.expand
        result =
          page.has_css?(
            "#understood-languages-selector button.selected-choice" \
              "[data-value='#{locale}']:not(:disabled)",
          )
        understood_languages_dropdown.collapse
        result
      end

      def has_no_understood_language?(locale)
        understood_languages_dropdown.expand
        result =
          page.has_no_css?(
            "#understood-languages-selector .selected-choice[data-value='#{locale}']",
          )
        understood_languages_dropdown.collapse
        result
      end

      def has_understood_language_option?(locale)
        understood_languages_dropdown.expand
        result =
          page.has_css?("#understood-languages-selector .select-kit-row[data-value='#{locale}']")
        understood_languages_dropdown.collapse
        result
      end

      def light_scheme_dropdown
        PageObjects::Components::SelectKit.new(".light-color-scheme .select-kit")
      end

      def dark_scheme_dropdown
        PageObjects::Components::SelectKit.new(".dark-color-scheme .select-kit")
      end

      def has_light_scheme_css?(color_scheme)
        expect(page).to have_css(
          "link.light-scheme[data-scheme-id=\"#{color_scheme.id}\"]",
          visible: false,
        )
      end

      def has_dark_scheme_css?(color_scheme)
        expect(page).to have_css(
          "link.dark-scheme[data-scheme-id=\"#{color_scheme.id}\"]",
          visible: false,
        )
      end

      def color_mode_dropdown
        PageObjects::Components::SelectKit.new(".interface-color-mode .select-kit")
      end

      def default_palette_and_mode_for_all_devices_checkbox
        find(".color-scheme-checkbox input[type='checkbox']")
      end

      def has_no_default_palette_and_mode_for_all_devices_checkbox?
        has_no_css?(".color-scheme-checkbox input[type='checkbox']")
      end

      def save_changes
        find(".save-changes").click
        expect(page).to have_css(".saved")
        self
      end

      private

      def understood_languages_dropdown
        PageObjects::Components::SelectKit.new("#understood-languages-selector")
      end
    end
  end
end
