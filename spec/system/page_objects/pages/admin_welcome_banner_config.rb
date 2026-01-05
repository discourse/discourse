# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminWelcomeBannerConfig < PageObjects::Pages::Base
      def visit
        page.visit("/admin/config/welcome-banner")
      end

      def has_locale_selector?
        has_css?(".translation-selector")
      end

      def select_locale(locale_value)
        find(".translation-selector").click
        find(".select-kit-row[data-value='#{locale_value}']").click
      end

      def selected_locale_name
        find(".translation-selector .select-kit-header .name").text
      end

      def header_new_members_value
        find("input[name='headerNewMembers']").value
      end

      def header_logged_in_value
        find("input[name='headerLoggedInMembers']").value
      end

      def header_anonymous_value
        find("input[name='headerAnonymousMembers']").value
      end

      def search_placeholder_value
        find("input[name='searchPlaceholder']").value
      end

      def has_disabled_inputs?
        has_css?("input[name='headerNewMembers'][disabled]")
      end

      def has_enabled_inputs?
        has_css?("input[name='headerNewMembers']:not([disabled])")
      end

      def fill_header_new_members(value)
        find("input[name='headerNewMembers']").fill_in(with: value)
      end

      def submit
        find("button[type='submit']").click
      end

      def has_saved_message?
        page.has_content?(I18n.t("admin_js.admin.config.welcome_banner.saved"))
      end
    end
  end
end
