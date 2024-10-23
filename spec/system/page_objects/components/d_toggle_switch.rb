# frozen_string_literal: true

module PageObjects
  module Components
    class DToggleSwitch < PageObjects::Components::Base
      attr_reader :context

      def initialize(context)
        @context = context
      end

      def toggle
        find(@context).click
      end

      def checked?
        find(@context).has_css?(".d-toggle-switch__checkbox[aria-checked=\"true\"]", visible: false)
      end

      def unchecked?
        find(@context).has_css?(
          ".d-toggle-switch__checkbox[aria-checked=\"false\"]",
          visible: false,
        )
      end
    end
  end
end
