# frozen_string_literal: true

module PageObjects
  module Components
    class AdminDashboardEngagement < PageObjects::Components::Base
      SECTION = "[data-section-id='engagement']"
      CATEGORY_FILTER = "#{SECTION} .category-selector"
      ACTIVITY_CATEGORY_CELL = "#{SECTION} .db-activity-table__cell-category"

      def category_filter
        PageObjects::Components::SelectKit.new(CATEGORY_FILTER)
      end

      def expand_category_filter
        category_filter.expand
        self
      end

      def deselect_category(category)
        expand_category_filter
        find("#{CATEGORY_FILTER} .selected-choice[data-value='#{category.id}']").click
        self
      end

      def has_activity_row?(category)
        has_css?(ACTIVITY_CATEGORY_CELL, text: category.name)
      end

      def has_no_activity_row?(category)
        has_no_css?(ACTIVITY_CATEGORY_CELL, text: category.name)
      end

      def has_selected_category?(category)
        has_css?("#{CATEGORY_FILTER} .selected-choice[data-value='#{category.id}']")
      end
    end
  end
end
