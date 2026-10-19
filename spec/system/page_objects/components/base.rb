# frozen_string_literal: true

module PageObjects
  module Components
    class Base
      include NativeSystemHelpers
      include RSpec::Matchers
      include Playwright::Test::Matchers
      include SystemHelpers

      def context_component
        browser_root.locator(@context).filter(visible: true)
      end
    end
  end
end
