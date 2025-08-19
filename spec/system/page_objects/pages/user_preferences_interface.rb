# frozen_string_literal: true

module PageObjects
  module Pages
    class UserPreferencesInterface < PageObjects::Pages::Base
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
        click_button "Save Changes"
        expect(page).to have_content(I18n.t("js.saved"))
        self
      end
    end
  end
end
