# frozen_string_literal: true

module PageObjects
  module Modals
    class Base
      include Capybara::DSL
      include RSpec::Matchers

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
        find(".modal-footer .btn-primary").click
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
