# frozen_string_literal: true

module PageObjects
  module Modals
    class ConfirmSession < PageObjects::Pages::Base
      def click_forgot_password
        browser_root
          .locator(".confirm-session .confirm-session__reset-btn")
          .filter(visible: true)
          .click
        self
      end

      def has_forgot_password_email_sent?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(".confirm-session .confirm-session__reset-email-sent").filter(
            visible: true,
          ),
        )
      end

      def submit_password(password)
        browser_root.locator(".confirm-session input#password").filter(visible: true).fill(password)
        browser_root
          .locator(".confirm-session .btn-primary:not([disabled])")
          .filter(visible: true)
          .click
        self
      end
    end
  end
end
