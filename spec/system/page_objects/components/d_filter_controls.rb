# frozen_string_literal: true

module PageObjects
  module Components
    class DFilterControls < PageObjects::Components::Base
      def initialize(component_selector, has_multiple_dropdowns: false)
        @component_selector = component_selector
        @has_multiple_dropdowns = has_multiple_dropdowns
      end

      def component
        browser_root.locator(@component_selector).filter(visible: true)
      end

      def type_in_search(input)
        component.locator(".d-filter-controls__input").filter(visible: true).fill(input)
      end

      def clear_search
        component.locator(".d-filter-controls__input").filter(visible: true).fill("")
      end

      def select_dropdown_option(text, dropdown_id: nil)
        selector = ".d-filter-controls__dropdown"
        selector += "#{selector}--#{dropdown_id}" if dropdown_id
        component.locator(selector).filter(visible: true).select_option(label: text)
      end

      def select_all_dropdown_option(dropdown_id: nil)
        selector = ".d-filter-controls__dropdown"
        selector += "#{selector}--#{dropdown_id}" if dropdown_id
        browser_root.locator(selector).filter(visible: true).select_option(value: "all")
      end

      def toggle_dropdown_filters
        component.locator(".d-filter-controls__toggle-filters").filter(visible: true).click
      end

      def has_no_results_reset_button?
        have_count(0).does_not_match?(
          browser_root.locator(".d-filter-controls__no-results .d-filter-controls__reset").filter(
            visible: true,
          ),
        )
      end

      def has_disabled_reset_button?
        have_count(0).does_not_match?(
          component.locator(".d-filter-controls__reset:disabled").filter(visible: true),
        )
      end

      def click_reset_button
        component.locator(".d-filter-controls__reset").filter(visible: true).click
      end

      def click_no_results_reset_button
        browser_root
          .locator(".d-filter-controls__no-results .d-filter-controls__reset")
          .filter(visible: true)
          .click
      end

      def has_no_no_results_reset_button?
        have_count(0).matches?(
          browser_root.locator(".d-filter-controls__no-results .d-filter-controls__reset").filter(
            visible: true,
          ),
        )
      end

      def has_no_results_message?
        have_count(0).does_not_match?(
          browser_root.locator(".d-filter-controls__no-results").filter(visible: true),
        )
      end

      def search_input_value
        component.locator(".d-filter-controls__input").filter(visible: true).input_value
      end

      def has_dropdown_value?(text, dropdown_id: nil)
        selector = ".d-filter-controls__dropdown"
        selector += "#{selector}--#{dropdown_id}" if dropdown_id
        contain_text([browser_text_pattern(text)], useInnerText: true).matches?(
          component.locator("#{selector} option:checked"),
        )
      end

      def dropdown_value
        component.locator(".d-filter-controls__dropdown option:checked").inner_text.strip
      end
    end
  end
end
