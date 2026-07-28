# frozen_string_literal: true

module PageObjects
  module Components
    class AdminDashboardEngagement < PageObjects::Components::Base
      SECTION = "[data-section-id='engagement']"
      ACTIVITY_CATEGORY_FILTER = "#{SECTION} .db-activity .category-selector"
      WHOS_POSTING_CATEGORY_FILTER = "#{SECTION} .db-whos-posting .category-selector"
      ACTIVITY_CATEGORY_CELL = "#{SECTION} .db-activity-table__cell-category"

      def activity_category_filter
        PageObjects::Components::SelectKit.new(ACTIVITY_CATEGORY_FILTER)
      end

      def whos_posting_category_filter
        PageObjects::Components::SelectKit.new(WHOS_POSTING_CATEGORY_FILTER)
      end

      def expand_activity_category_filter
        activity_category_filter.expand
        self
      end

      def expand_whos_posting_category_filter
        whos_posting_category_filter.expand
        self
      end

      def deselect_activity_category(category)
        expand_activity_category_filter
        find("#{ACTIVITY_CATEGORY_FILTER} .selected-choice[data-value='#{category.id}']").click
        self
      end

      def deselect_whos_posting_category(category)
        expand_whos_posting_category_filter
        find("#{WHOS_POSTING_CATEGORY_FILTER} .selected-choice[data-value='#{category.id}']").click
        self
      end

      def select_whos_posting_category(category)
        expand_whos_posting_category_filter
        whos_posting_category_filter.select_row_by_value(category.id)
        self
      end

      def close_whos_posting_category_filter
        whos_posting_category_filter.collapse
        self
      end

      def has_activity_row?(category)
        has_css?(ACTIVITY_CATEGORY_CELL, text: category.name)
      end

      def has_no_activity_row?(category)
        has_no_css?(ACTIVITY_CATEGORY_CELL, text: category.name)
      end

      def has_selected_activity_category?(category)
        has_css?("#{ACTIVITY_CATEGORY_FILTER} .selected-choice[data-value='#{category.id}']")
      end

      def has_selected_whos_posting_category?(category)
        has_css?("#{WHOS_POSTING_CATEGORY_FILTER} .selected-choice[data-value='#{category.id}']")
      end

      def has_no_selected_whos_posting_category?(category)
        has_no_css?("#{WHOS_POSTING_CATEGORY_FILTER} .selected-choice[data-value='#{category.id}']")
      end
    end
  end
end
