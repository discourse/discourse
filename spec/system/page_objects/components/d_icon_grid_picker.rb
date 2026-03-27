# frozen_string_literal: true

module PageObjects
  module Components
    class DIconGridPicker < PageObjects::Components::Base
      def expand
        find(".d-icon-grid-picker-trigger").click
      end

      def select_icon(icon_id)
        find("[data-icon-id='#{icon_id}']").click
      end

      def select_first_icon
        find("[data-icon-id]", match: :first).click
      end

      def clear
        find(".d-icon-grid-picker__clear").click
      end

      def has_selected_icon?(icon_id)
        page.has_css?(".d-icon-grid-picker-trigger .d-icon-#{icon_id}")
      end

      def has_no_selected_icon?
        page.has_no_css?(".d-icon-grid-picker-trigger .d-icon")
      end

      def has_clear_button?
        page.has_css?(".d-icon-grid-picker__clear")
      end

      def has_no_clear_button?
        page.has_no_css?(".d-icon-grid-picker__clear")
      end
    end
  end
end
