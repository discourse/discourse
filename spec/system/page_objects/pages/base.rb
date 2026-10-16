# frozen_string_literal: true

module PageObjects
  module Pages
    class Base
      include NativeSystemHelpers
      include RSpec::Matchers
      include Playwright::Test::Matchers
      include SystemHelpers
    end
  end
end
