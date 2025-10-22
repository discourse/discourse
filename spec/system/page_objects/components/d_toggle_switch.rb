# frozen_string_literal: true

module PageObjects
  module Components
    class DToggleSwitch < PageObjects::Components::Base
      attr_reader :context

      def initialize(context)
        @context = context
      end

      def label_component
        find(context, visible: :all).ancestor("label.d-toggle-switch__label")
      end

      def toggle
        label_component.click
      end

      def checked?
        label_component.has_css?(".d-toggle-switch__checkbox[aria-checked=\"true\"]", visible: :all)
      end

      def unchecked?
        label_component.has_css?(
          ".d-toggle-switch__checkbox[aria-checked=\"false\"]",
          visible: :all,
        )
      end

      def disabled?
        label_component.has_css?(".d-toggle-switch__checkbox[disabled]", visible: :all)
      end

      def enabled?
        label_component.has_no_css?(".d-toggle-switch__checkbox[disabled]", visible: :all) &&
          label_component.has_css?(".d-toggle-switch__checkbox", visible: :all)
      end
    end
  end
end
