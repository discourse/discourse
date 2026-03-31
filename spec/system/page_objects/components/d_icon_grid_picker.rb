# frozen_string_literal: true

module PageObjects
  module Components
    class DIconGridPicker < PageObjects::Components::Base
      def initialize(scope = nil)
        @scope = scope
      end

      def expand
        trigger.click
      end

      def select_icon(icon_id)
        find("[data-icon-id='#{icon_id}']").click
      end

      def select_first_icon
        find("[data-icon-id]", match: :first).click
      end

      def filter(term)
        find(".d-icon-grid-picker__filter .filter-input").fill_in(with: term)
      end

      def clear
        scoped(".d-icon-grid-picker__clear").click
      end

      def value
        wrapper["data-value"]
      end

      def has_selected_icon?(icon_id)
        wrapper["data-value"] == icon_id
      end

      def has_no_selected_icon?
        wrapper["data-value"].blank?
      end

      def has_clear_button?
        scoped(".d-icon-grid-picker__clear", wait: false).present?
      rescue Capybara::ElementNotFound
        false
      end

      def has_no_clear_button?
        !has_clear_button?
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
        when Capybara::Node::Element
          @scope.find(selector)
        when String
          find("#{@scope} #{selector}")
        else
          find(selector)
        end
      end
    end
  end
end
