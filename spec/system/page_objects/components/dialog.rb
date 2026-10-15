# frozen_string_literal: true

module PageObjects
  module Components
    class Dialog < PageObjects::Components::Base
      def closed?
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(".dialog-container").filter(visible: true),
        )
      end

      def open?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(".dialog-container").filter(visible: true),
        )
      end

      def has_displayed_content?(content)
        PlaywrightMatchers.contain_text(browser_text_pattern(content), useInnerText: true).matches?(
          browser_root.locator(".dialog-container").filter(visible: true),
        )
      end

      def click_yes
        browser_root.locator(".dialog-footer .btn-primary").filter(visible: true).click
      end

      def click_danger
        browser_root.locator(".dialog-footer .btn-danger").filter(visible: true).click
      end

      alias click_ok click_yes

      def click_no
        browser_root.locator(".dialog-footer .btn-default").filter(visible: true).click
      end

      def has_confirm_button_disabled?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(".dialog-footer .btn-danger[disabled]").filter(visible: true),
        )
      end

      def has_no_confirm_button_disabled?
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(".dialog-footer .btn-danger[disabled]").filter(visible: true),
        )
      end

      def fill_in_confirmation_phrase(phrase)
        browser_root
          .locator(".dialog-body input.confirmation-phrase")
          .filter(visible: true)
          .fill(phrase)
      end
    end
  end
end
