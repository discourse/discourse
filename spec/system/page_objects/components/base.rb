# frozen_string_literal: true

module PageObjects
  module Components
    class Base
      include Capybara::DSL
      include RSpec::Matchers
    end
  end
end
