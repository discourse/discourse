# frozen_string_literal: true

module PageObjects
  module Components
    class Base
      include Capybara::DSL
      include RSpec::Matchers
      include SystemHelpers

      def context_component
        page.find(@context)
      end
    end
  end
end
