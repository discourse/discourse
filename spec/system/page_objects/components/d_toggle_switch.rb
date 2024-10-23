# frozen_string_literal: true

module PageObjects
  module Components
    class DToggleSwitch < PageObjects::Components::Base
      attr_reader :context

      def initialize(context)
        @context = context
      end

      def component
        find(context, visible: :all)
      end

      def toggle
        # scroll_to(component)
        component.find(".d-toggle-switch__label").click
      end

      def checked?
        component.has_css?(".d-toggle-switch__checkbox[aria-checked=\"true\"]", visible: :all)
      end

      def unchecked?
        component.has_css?(".d-toggle-switch__checkbox[aria-checked=\"false\"]", visible: :all)
      end
    end
  end
end
