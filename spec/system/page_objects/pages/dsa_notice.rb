# frozen_string_literal: true

module PageObjects
  module Pages
    class DsaNotice < Base
      def form
        PageObjects::Components::FormKit.new(".dsa-notice .form-kit")
      end

      def has_notice_form?
        has_css?(".dsa-notice .form-kit")
      end

      def request_email_code
        click_button("Get email code")
      end

      def fill_verification_code(code)
        page.driver.with_playwright_page do |browser_page|
          browser_page.locator(".dsa-notice .d-otp-input").fill(code)
        end
      end

      def has_verified_email?
        has_button?("Verified", disabled: true)
      end

      def has_confirmation?
        has_css?(".dsa-notice h1", text: "Report received")
      end
    end
  end
end
