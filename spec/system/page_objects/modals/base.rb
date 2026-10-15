# frozen_string_literal: true

module PageObjects
  module Modals
    class Base
      include SystemHelpers
      include NativeSystemHelpers
      include RSpec::Matchers

      BODY_SELECTOR = ""
      MODAL_SELECTOR = ""

      def initialize(body_selector: MODAL_SELECTOR, modal_selector: MODAL_SELECTOR)
        # This can be used as an alternative to making a whole new
        # modal PageObject when there isn't a lot of specific custom stuff
        # in that modal's UI -- in many cases just having the modal scoping
        # is enough.
        @body_selector = body_selector
        @modal_selector = modal_selector
      end

      def full_body_selector
        ".d-modal__body#{@body_selector}"
      end

      def full_modal_selector
        ".d-modal#{@modal_selector}"
      end

      def footer_selector
        "#{full_modal_selector} .d-modal__footer"
      end

      def header
        browser_root.locator(".d-modal__header").filter(visible: true)
      end

      def body
        browser_root.locator(full_body_selector).filter(visible: true)
      end

      def footer
        browser_root.locator(footer_selector).filter(visible: true)
      end

      def has_footer?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(footer_selector).filter(visible: true),
        )
      end

      def has_no_footer?
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(footer_selector).filter(visible: true),
        )
      end

      def close
        browser_root.locator("#{full_modal_selector} .modal-close").filter(visible: true).click
      end

      def cancel
        browser_root.locator("#{full_modal_selector} .d-modal-cancel").filter(visible: true).click
      end

      def click_outside
        browser_root
          .locator("#{full_modal_selector}")
          .filter(visible: true)
          .click(position: { x: 0, y: 0 })
      end

      def click_primary_button
        footer.locator(".btn-primary").filter(visible: true).click
      end

      def has_displayed_content?(content)
        PlaywrightMatchers.contain_text(browser_text_pattern(content), useInnerText: true).matches?(
          body,
        )
      end

      def open?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(full_modal_selector).filter(visible: true),
        )
      end

      def closed?
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(full_modal_selector).filter(visible: true),
        )
      end
    end
  end
end
