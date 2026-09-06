# frozen_string_literal: true

module PageObjects
  module Components
    class AdminDashboardEngagement < PageObjects::Components::Base
      SECTION = "[data-section-id='engagement']"
      ACTIVITY_CATEGORY_FILTER = "#{SECTION} .db-activity .multiple-categories-selector"
      WHOS_POSTING_CATEGORY_FILTER = "#{SECTION} .db-whos-posting .multiple-categories-selector"
      ACTIVITY_CATEGORY_CELL = "#{SECTION} .db-activity-table__cell-category"
      ADD_GROUP_BUTTON = "#{SECTION} .db-whos-posting__add-group"
      WHOS_POSTING_BAR_LABEL = "#{SECTION} .db-whos-posting__bar-label"

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

      def compare_groups_modal
        @compare_groups_modal ||=
          PageObjects::Components::ManageableRowListModal.new(
            ".compare-groups",
            "admin_js.admin.dashboard.sections.engagement.whos_posting.modal.counter",
          )
      end

      def open_compare_groups_modal
        find(ADD_GROUP_BUTTON).click
        compare_groups_modal.has_open?
        self
      end

      def toggle_compare_groups_row(identifier)
        compare_groups_modal.toggle(identifier)
        self
      end

      def apply_compare_groups
        compare_groups_modal.apply
        compare_groups_modal.has_closed?
        self
      end

      def has_whos_posting_bar?(name)
        has_css?(WHOS_POSTING_BAR_LABEL, text: name)
      end

      def has_no_whos_posting_bar?(name)
        has_no_css?(WHOS_POSTING_BAR_LABEL, text: name)
      end

      def has_headline?(title, summary)
        has_css?("#{SECTION} .db-section__subintro h3", exact_text: title) &&
          has_css?("#{SECTION} .db-section__subintro p", exact_text: summary)
      end
    end
  end
end
