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
    end
  end
end
