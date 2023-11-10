# frozen_string_literal: true

module PageObjects
  module Modals
    class Base
      include Capybara::DSL
      include RSpec::Matchers

      BODY_SELECTOR = ""

      def body
        find(".modal-body#{BODY_SELECTOR}")
      end

      def footer
        find(".modal-footer")
      end

      def close
        find(".modal-close").click
      end

      def cancel
        find(".d-modal-cancel").click
      end

      def click_outside
        find(".modal-outer-container").click(x: 0, y: 0)
      end

      def click_primary_button
        footer.find(".btn-primary").click
      end

      def has_content?(content)
        body.has_content?(content)
      end

      def open?
        has_css?(".modal.d-modal")
      end

      def closed?
        has_no_css?(".modal.d-modal")
      end
    end
  end
end
