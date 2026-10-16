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
        browser_root
          .locator("#{ACTIVITY_CATEGORY_FILTER} .selected-choice[data-value='#{category.id}']")
          .filter(visible: true)
          .click
        self
      end

      def deselect_whos_posting_category(category)
        expand_whos_posting_category_filter
        browser_root
          .locator("#{WHOS_POSTING_CATEGORY_FILTER} .selected-choice[data-value='#{category.id}']")
          .filter(visible: true)
          .click
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
        contain_text([browser_text_pattern(category.name)], useInnerText: true).matches?(
          browser_root.locator(ACTIVITY_CATEGORY_CELL).filter(visible: true),
        )
      end

      def has_no_activity_row?(category)
        contain_text([browser_text_pattern(category.name)], useInnerText: true).does_not_match?(
          browser_root.locator(ACTIVITY_CATEGORY_CELL).filter(visible: true),
        )
      end

      def has_selected_activity_category?(category)
        have_count(0).does_not_match?(
          browser_root.locator(
            "#{ACTIVITY_CATEGORY_FILTER} .selected-choice[data-value='#{category.id}']",
          ).filter(visible: true),
        )
      end

      def has_selected_whos_posting_category?(category)
        have_count(0).does_not_match?(
          browser_root.locator(
            "#{WHOS_POSTING_CATEGORY_FILTER} .selected-choice[data-value='#{category.id}']",
          ).filter(visible: true),
        )
      end

      def has_no_selected_whos_posting_category?(category)
        have_count(0).matches?(
          browser_root.locator(
            "#{WHOS_POSTING_CATEGORY_FILTER} .selected-choice[data-value='#{category.id}']",
          ).filter(visible: true),
        )
      end

      def has_activity_row_with_parent?(category)
        have_count(0).does_not_match?(
          browser_root.locator(
            "#{ACTIVITY_CATEGORY_CELL} #{parent_then_child_badges(category)}",
          ).filter(visible: true),
        )
      end

      def has_selected_activity_category_with_parent?(category)
        have_count(0).does_not_match?(
          browser_root.locator(
            "#{ACTIVITY_CATEGORY_FILTER} .selected-choice[data-value='#{category.id}'] " \
              "#{parent_then_child_badges(category)}",
          ).filter(visible: true),
        )
      end

      def has_selected_whos_posting_category_with_parent?(category)
        have_count(0).does_not_match?(
          browser_root.locator(
            "#{WHOS_POSTING_CATEGORY_FILTER} .selected-choice[data-value='#{category.id}'] " \
              "#{parent_then_child_badges(category)}",
          ).filter(visible: true),
        )
      end

      def compare_groups_modal
        @compare_groups_modal ||=
          PageObjects::Components::ManageableRowListModal.new(
            ".compare-groups",
            "admin_js.admin.dashboard.sections.engagement.whos_posting.modal.counter",
          )
      end

      def open_compare_groups_modal
        browser_root.locator(ADD_GROUP_BUTTON).filter(visible: true).click
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
        contain_text([browser_text_pattern(name)], useInnerText: true).matches?(
          browser_root.locator(WHOS_POSTING_BAR_LABEL).filter(visible: true),
        )
      end

      def has_no_whos_posting_bar?(name)
        contain_text([browser_text_pattern(name)], useInnerText: true).does_not_match?(
          browser_root.locator(WHOS_POSTING_BAR_LABEL).filter(visible: true),
        )
      end

      def has_headline?(title, summary)
        contain_text([browser_exact_text_pattern(title)], useInnerText: true).matches?(
          browser_root.locator("#{SECTION} .db-section__subintro h3").filter(visible: true),
        ) &&
          contain_text([browser_exact_text_pattern(summary)], useInnerText: true).matches?(
            browser_root.locator("#{SECTION} .db-section__subintro p").filter(visible: true),
          )
      end

      private

      def parent_then_child_badges(category)
        ".badge-category__wrapper:has(.badge-category[data-category-id='#{category.parent_category_id}']) + " \
          ".badge-category__wrapper .badge-category[data-category-id='#{category.id}']"
      end
    end
  end
end
