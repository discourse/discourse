# frozen_string_literal: true

module PageObjects
  module Modals
    class Base
      include Capybara::DSL
      include RSpec::Matchers

      BODY_SELECTOR = ""
      MODAL_SELECTOR = ""

      def header
        find(".d-modal__header")
      end

      def body
        find(".d-modal__body#{BODY_SELECTOR}")
      end

      def footer
        find(".d-modal__footer")
      end

      def has_footer?
        has_css?(".d-modal__footer")
      end

      def has_no_footer?
        has_no_css?(".d-modal__footer")
      end

      def close
        find(".modal-close").click
      end

      def cancel
        find(".d-modal-cancel").click
      end

      def click_outside
        find(".d-modal").click(x: 0, y: 0)
      end

      def click_primary_button
        footer.find(".btn-primary").click
      end

      def has_content?(content)
        body.has_content?(content)
      end

      def open?
        has_css?(".modal.d-modal#{MODAL_SELECTOR}")
      end

      def closed?
        has_no_css?(".modal.d-modal#{MODAL_SELECTOR}")
      end
    end
  end
end
