# frozen_string_literal: true

module PageObjects
  module Modals
    class Base
      include Capybara::DSL
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
        ".modal.d-modal#{@modal_selector}"
      end

      def footer_selector
        "#{full_modal_selector} .d-modal__footer"
      end

      def header
        find(".d-modal__header")
      end

      def body
        find(full_body_selector)
      end

      def footer
        find(footer_selector)
      end

      def has_footer?
        has_css?(footer_selector)
      end

      def has_no_footer?
        has_no_css?(footer_selector)
      end

      def close
        find("#{full_modal_selector} .modal-close").click
      end

      def cancel
        find("#{full_modal_selector} .d-modal-cancel").click
      end

      def click_outside
        find("#{full_modal_selector}").click(x: 0, y: 0)
      end

      def click_primary_button
        footer.find(".btn-primary").click
      end

      def has_content?(content)
        body.has_content?(content)
      end

      def open?
        has_css?(full_modal_selector)
      end

      def closed?
        has_no_css?(full_modal_selector)
      end
    end
  end
end
