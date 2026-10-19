# frozen_string_literal: true

module PageObjects
  module Components
    class DIconGridPicker < PageObjects::Components::Base
      def initialize(scope = nil)
        @scope = scope
      end

      def expand
        trigger.click
        self
      end

      def select_icon(icon_id)
        filter(icon_id)
        browser_root.locator("[data-icon-id='#{icon_id}']").filter(visible: true).click
      end

      def select_first_icon
        browser_root.locator("[data-icon-id]").filter(visible: true).first.click
      end

      def filter(term)
        filter_input.fill(term)
      end

      def type_filter(term)
        filter_input.press_sequentially(term)
        self
      end

      def filter_input
        browser_root.locator(".d-icon-grid-picker__filter .filter-input").filter(visible: true)
      end

      def has_icon?(icon_id)
        have_count(0).does_not_match?(
          browser_root.locator("[data-icon-id='#{icon_id}']").filter(visible: true),
        )
      end

      def clear
        scoped(".d-icon-grid-picker__clear").click
      end

      def value
        wrapper.get_attribute("data-value")
      end

      def has_selected_icon?(icon_id)
        wrapper.get_attribute("data-value") == icon_id
      end

      def has_no_selected_icon?
        wrapper.get_attribute("data-value").blank?
      end

      def has_clear_button?
        scoped_has_css?(".d-icon-grid-picker__clear")
      end

      def has_no_clear_button?
        scoped_has_no_css?(".d-icon-grid-picker__clear")
      end

      private

      def wrapper
        scoped(".d-icon-grid-picker")
      end

      def trigger
        scoped(".d-icon-grid-picker-trigger")
      end

      def scoped(selector)
        case @scope
        when Playwright::Locator
          @scope.locator(selector).filter(visible: true)
        when String
          browser_root.locator("#{@scope} #{selector}").filter(visible: true)
        else
          browser_root.locator(selector).filter(visible: true)
        end
      end

      def scoped_has_css?(selector)
        have_count(0).does_not_match?(scoped(selector))
      end

      def scoped_has_no_css?(selector)
        have_count(0).matches?(scoped(selector))
      end
    end
  end
end
