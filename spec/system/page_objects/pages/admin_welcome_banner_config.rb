# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminWelcomeBannerConfig < PageObjects::Pages::Base
      def visit
        browser_page
          .goto("/admin/config/welcome-banner")
          .tap { SystemBrowserBootstrap.wait_for(browser_page) }
      end

      def form
        @form ||= PageObjects::Components::FormKit.new(".admin-welcome-banner-form")
      end

      def has_locale_selector?
        have_count(0).does_not_match?(
          browser_root.locator(".translation-selector").filter(visible: true),
        )
      end

      def select_locale(locale_value)
        browser_root.locator(".translation-selector").filter(visible: true).click
        browser_root
          .locator(".select-kit-row[data-value='#{locale_value}']")
          .filter(visible: true)
          .click
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
        contain_text(
          browser_text_pattern(I18n.t("admin_js.admin.config.welcome_banner.saved")),
          useInnerText: true,
        ).matches?(browser_content)
      end
    end
  end
end
