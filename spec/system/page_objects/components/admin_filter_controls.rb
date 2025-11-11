# frozen_string_literal: true

module PageObjects
  module Components
    class AdminFilterControls < PageObjects::Components::Base
      def initialize(component_selector, has_multiple_dropdowns: false)
        @component_selector = component_selector
        @has_multiple_dropdowns = has_multiple_dropdowns
      end

      def component
        find(@component_selector)
      end

      def type_in_search(input)
        component.find(".admin-filter-controls__input").send_keys(input)
      end

      def clear_search
        component.find(".admin-filter-controls__input").set("")
      end

      def select_dropdown_option(text, dropdown_id: nil)
        selector = ".admin-filter-controls__dropdown"
        selector += "#{selector}--#{dropdown_id}" if dropdown_id
        component.find(selector).select(text)
      end

      def select_all_dropdown_option(dropdown_id: nil)
        selector = ".admin-filter-controls__dropdown"
        selector += "#{selector}--#{dropdown_id}" if dropdown_id
        find(selector).find("option[value='all']").select_option
      end

      def toggle_dropdown_filters
        component.find(".admin-filter-controls__toggle-filters").click
      end

      def has_reset_button?
        page.has_css?(".admin-filter-controls__reset")
      end

      def click_reset_button
        page.find(".admin-filter-controls__reset").click
      end

      def has_no_reset_button?
        component.has_no_css?(".admin-filter-controls__reset")
      end

      def has_no_results_message?
        page.has_css?(".admin-filter-controls__no-results")
      end

      def search_input_value
        component.find(".admin-filter-controls__input").value
      end

      def dropdown_value
        component.find(".admin-filter-controls__dropdown option:checked").text
      end
    end
  end
end
