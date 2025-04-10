# frozen_string_literal: true

module PageObjects
  module Components
    class DSelect < PageObjects::Components::Base
      attr_reader :select_element

      def initialize(input)
        if input.is_a?(Capybara::Node::Element)
          @select_element = input
        else
          @select_element = find(input)
        end
      end

      def value
        @select_element.value
      end

      def select(value)
        @select_element.find("option[value='#{value}']").select_option
        @select_element.execute_script(<<~JS, @select_element)
          var selector = arguments[0];
          selector.dispatchEvent(new Event("input", { bubbles: true, cancelable: true }));
        JS
      end
    end
  end
end
