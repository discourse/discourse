# frozen_string_literal: true

module PageObjects
  module Components
    class Base
      include Capybara::DSL
      include RSpec::Matchers
      include SystemHelpers
    end
  end
end
