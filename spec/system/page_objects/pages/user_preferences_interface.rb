# frozen_string_literal: true

module PageObjects
  module Pages
    class UserPreferencesInterface < PageObjects::Pages::Base
      AUTOMATIC_TRANSLATION_SELECTOR =
        "[data-setting-name='user-content-languages'] " \
          "[data-setting-name='user-automatically-translate'] input"

      def visit(user)
        browser_page
          .goto("/u/#{user.username}/preferences/interface")
          .tap { SystemBrowserBootstrap.wait_for(browser_page) }
        self
      end

      def has_bookmark_after_notification_mode?(value)
        have_count(0).does_not_match?(
          browser_root.locator(
            "#bookmark-after-notification-mode .select-kit-header[data-value=\"#{value}\"]",
          ).filter(visible: true),
        )
      end

      def select_bookmark_after_notification_mode(value)
        browser_root.locator("#bookmark-after-notification-mode").filter(visible: true).click
        browser_root.locator(".select-kit-row[data-value=\"#{value}\"]").filter(visible: true).click
        self
      end

      def theme_dropdown
        PageObjects::Components::SelectKit.new("[data-setting-name='user-theme'] .combo-box")
      end

      def text_size_dropdown
        PageObjects::Components::SelectKit.new("[data-setting-name='user-text-size'] .combo-box")
      end

      def has_interface_language_section?
        have_count(0).does_not_match?(
          browser_root.locator("[data-setting-name='user-locale'] .control-label").filter(
            visible: true,
          ),
        )
      end

      def has_no_interface_language_section?
        have_count(0).matches?(
          browser_root.locator("[data-setting-name='user-locale'] .control-label").filter(
            visible: true,
          ),
        )
      end

      def has_content_languages_section?
        have_count(0).does_not_match?(
          browser_root.locator(
            "[data-setting-name='user-content-languages'] .control-label",
          ).filter(visible: true),
        )
      end

      def automatic_translation_enabled?
        have_count(0).does_not_match?(
          browser_root.locator("#{AUTOMATIC_TRANSLATION_SELECTOR}:checked").filter(visible: true),
        )
      end

      def automatic_translation_disabled?
        have_count(0).matches?(
          browser_root.locator("#{AUTOMATIC_TRANSLATION_SELECTOR}:checked").filter(visible: true),
        )
      end

      def disable_automatic_translation
        browser_root
          .locator("#{AUTOMATIC_TRANSLATION_SELECTOR}:checked")
          .filter(visible: true)
          .click
        self
      end

      def enable_automatic_translation
        browser_root
          .locator("#{AUTOMATIC_TRANSLATION_SELECTOR}:not(:checked)")
          .filter(visible: true)
          .click
        self
      end

      def has_removable_understood_language?(locale)
        understood_languages_dropdown.expand
        result =
          have_count(0).does_not_match?(
            browser_root.locator(
              "#understood-languages-selector button.selected-choice" \
                "[data-value='#{locale}']:not(:disabled)",
            ).filter(visible: true),
          )
        understood_languages_dropdown.collapse
        result
      end

      def has_no_understood_language?(locale)
        understood_languages_dropdown.expand
        result =
          have_count(0).matches?(
            browser_root.locator(
              "#understood-languages-selector .selected-choice[data-value='#{locale}']",
            ).filter(visible: true),
          )
        understood_languages_dropdown.collapse
        result
      end

      def has_understood_language_option?(locale)
        understood_languages_dropdown.expand
        result =
          have_count(0).does_not_match?(
            browser_root.locator(
              "#understood-languages-selector .select-kit-row[data-value='#{locale}']",
            ).filter(visible: true),
          )
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
        expect(
          browser_root.locator("link.light-scheme[data-scheme-id=\"#{color_scheme.id}\"]"),
        ).not_to have_count(0)
      end

      def has_dark_scheme_css?(color_scheme)
        expect(
          browser_root.locator("link.dark-scheme[data-scheme-id=\"#{color_scheme.id}\"]"),
        ).not_to have_count(0)
      end

      def color_mode_dropdown
        PageObjects::Components::SelectKit.new(".interface-color-mode .select-kit")
      end

      def default_palette_and_mode_for_all_devices_checkbox
        browser_root.locator(".color-scheme-checkbox input[type='checkbox']").filter(visible: true)
      end

      def has_no_default_palette_and_mode_for_all_devices_checkbox?
        have_count(0).matches?(
          browser_root.locator(".color-scheme-checkbox input[type='checkbox']").filter(
            visible: true,
          ),
        )
      end

      def save_changes
        browser_root.locator(".save-changes").filter(visible: true).click
        expect(browser_root.locator(".saved").filter(visible: true)).not_to have_count(0)
        self
      end

      private

      def understood_languages_dropdown
        PageObjects::Components::SelectKit.new("#understood-languages-selector")
      end
    end
  end
end
