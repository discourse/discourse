# frozen_string_literal: true

module PageObjects
  module Pages
    class Base
      include Capybara::DSL

      def setup_component_classes!(component_classes)
        @component_classes = component_classes
      end
    end
  end
end
