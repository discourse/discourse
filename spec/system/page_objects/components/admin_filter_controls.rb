# frozen_string_literal: true

module PageObjects
  module Components
    class AdminFilterControls < PageObjects::Components::Base
      def initialize(component_selector)
        @component_selector = component_selector
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

      def select_dropdown_option(text)
        component.find(".admin-filter-controls__dropdown").select(text)
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
