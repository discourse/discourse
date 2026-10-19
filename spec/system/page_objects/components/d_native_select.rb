# frozen_string_literal: true

module PageObjects
  module Components
    class DNativeSelect < PageObjects::Components::Base
      NO_VALUE_OPTION = "__NONE__"

      attr_reader :select_element

      def initialize(input)
        if input.is_a?(Playwright::Locator)
          @select_element = input
        else
          @select_element = browser_root.locator(input).filter(visible: true)
        end
      end

      def value
        @select_element.input_value
      end

      def select(value)
        @select_element.select_option(value: value.to_s)
        @select_element.evaluate(
          "element => element.dispatchEvent(new Event('input', { bubbles: true, cancelable: true }))",
        )
      end

      def has_no_value?
        have_count(0).does_not_match?(
          @select_element.locator("option[value='#{NO_VALUE_OPTION}']:checked"),
        )
      end
    end
  end
end
