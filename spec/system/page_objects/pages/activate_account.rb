# frozen_string_literal: true

module PageObjects
  module Pages
    class ActivateAccount < PageObjects::Pages::Base
      def click_activate_account
        browser_root.locator(".activate-account-button").filter(visible: true).click
      end

      def click_continue
        browser_root.locator(".account-activated .continue-button").filter(visible: true).click
      end

      def has_error?
        expect(
          browser_root.locator(".alert-error").filter(visible: true),
        ).not_to PlaywrightMatchers.have_count(0)
        PlaywrightMatchers.contain_text(
          browser_text_pattern(I18n.t("js.user.activate_account.already_done")),
          useInnerText: true,
        ).matches?(browser_content)
      end
    end
  end
end
