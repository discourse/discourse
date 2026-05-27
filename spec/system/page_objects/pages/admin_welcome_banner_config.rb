# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminWelcomeBannerConfig < PageObjects::Pages::Base
      def visit
        page.visit("/admin/config/welcome-banner")
      end

      def form
        @form ||= PageObjects::Components::FormKit.new(".admin-welcome-banner-form")
      end

      def has_locale_selector?
        has_css?(".translation-selector")
      end

      def select_locale(locale_value)
        find(".translation-selector").click
        find(".select-kit-row[data-value='#{locale_value}']").click
      end

      def header_new_members_value
        form.field("headerNewMembers").value
      end

      def search_placeholder_value
        form.field("searchPlaceholder").value
      end

      def fill_header_new_members(value)
        form.field("headerNewMembers").fill_in(value)
      end

      def submit
        form.submit
      end

      def has_saved_message?
        page.has_content?(I18n.t("admin_js.admin.config.welcome_banner.saved"))
      end
    end
  end
end
