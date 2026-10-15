# frozen_string_literal: true

module PageObjects
  module Components
    class DToggleSwitch < PageObjects::Components::Base
      attr_reader :context

      def initialize(context)
        @context = context
      end

      def label_component
        browser_root
          .locator(context)
          .locator("xpath=ancestor::*")
          .and(browser_page.locator("label.d-toggle-switch__label"))
          .last
      end

      def toggle
        label_component.click
      end

      def checked?
        PlaywrightMatchers.have_count(0).does_not_match?(
          label_component.locator(".d-toggle-switch__checkbox[aria-checked=\"true\"]"),
        )
      end

      def unchecked?
        PlaywrightMatchers.have_count(0).does_not_match?(
          label_component.locator(".d-toggle-switch__checkbox[aria-checked=\"false\"]"),
        )
      end

      def disabled?
        PlaywrightMatchers.have_count(0).does_not_match?(
          label_component.locator(".d-toggle-switch__checkbox[disabled]"),
        )
      end

      def enabled?
        PlaywrightMatchers.have_count(0).matches?(
          label_component.locator(".d-toggle-switch__checkbox[disabled]"),
        ) &&
          PlaywrightMatchers.have_count(0).does_not_match?(
            label_component.locator(".d-toggle-switch__checkbox"),
          )
      end
    end
  end
end
