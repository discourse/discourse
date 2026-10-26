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
        selector = ACTIVITY_CATEGORY_FILTER
        if find(selector).matches_css?(".d-select", wait: 0)
          PageObjects::Components::UiKit::DSelect.at(selector)
        else
          PageObjects::Components::SelectKit.new(selector)
        end
      end

      def whos_posting_category_filter
        selector = WHOS_POSTING_CATEGORY_FILTER
        if find(selector).matches_css?(".d-select", wait: 0)
          PageObjects::Components::UiKit::DSelect.at(selector)
        else
          PageObjects::Components::SelectKit.new(selector)
        end
      end

      def expand_activity_category_filter
        if activity_category_filter.is_a?(PageObjects::Components::UiKit::DSelect)
          activity_category_filter.open
        else
          activity_category_filter.expand
        end
        self
      end

      def expand_whos_posting_category_filter
        if whos_posting_category_filter.is_a?(PageObjects::Components::UiKit::DSelect)
          whos_posting_category_filter.open
        else
          whos_posting_category_filter.expand
        end
        self
      end

      def deselect_activity_category(category)
        expand_activity_category_filter
        if activity_category_filter.is_a?(PageObjects::Components::UiKit::DSelect)
          activity_category_filter.remove(category.id)
        else
          find(
            "#{ACTIVITY_CATEGORY_FILTER} #{category_choice_class(ACTIVITY_CATEGORY_FILTER)}[data-value='#{category.id}']",
          ).click
        end
        self
      end

      def deselect_whos_posting_category(category)
        expand_whos_posting_category_filter
        if whos_posting_category_filter.is_a?(PageObjects::Components::UiKit::DSelect)
          whos_posting_category_filter.remove(category.id)
        else
          find(
            "#{WHOS_POSTING_CATEGORY_FILTER} #{category_choice_class(WHOS_POSTING_CATEGORY_FILTER)}[data-value='#{category.id}']",
          ).click
        end
        self
      end

      def select_whos_posting_category(category)
        expand_whos_posting_category_filter
        if whos_posting_category_filter.is_a?(PageObjects::Components::UiKit::DSelect)
          whos_posting_category_filter.select_value(category.id)
        else
          whos_posting_category_filter.select_row_by_value(category.id)
        end
        self
      end

      def close_whos_posting_category_filter
        if whos_posting_category_filter.is_a?(PageObjects::Components::UiKit::DSelect)
          whos_posting_category_filter.close
        else
          whos_posting_category_filter.collapse
        end
        self
      end

      def has_activity_row?(category)
        has_css?(ACTIVITY_CATEGORY_CELL, text: category.name)
      end

      def has_no_activity_row?(category)
        has_no_css?(ACTIVITY_CATEGORY_CELL, text: category.name)
      end

      def has_selected_activity_category?(category)
        has_css?(
          "#{ACTIVITY_CATEGORY_FILTER} #{category_choice_class(ACTIVITY_CATEGORY_FILTER)}[data-value='#{category.id}']",
        )
      end

      def has_selected_whos_posting_category?(category)
        has_css?(
          "#{WHOS_POSTING_CATEGORY_FILTER} #{category_choice_class(WHOS_POSTING_CATEGORY_FILTER)}[data-value='#{category.id}']",
        )
      end

      def has_no_selected_whos_posting_category?(category)
        has_no_css?(
          "#{WHOS_POSTING_CATEGORY_FILTER} #{category_choice_class(WHOS_POSTING_CATEGORY_FILTER)}[data-value='#{category.id}']",
        )
      end

      def has_activity_row_with_parent?(category)
        has_css?("#{ACTIVITY_CATEGORY_CELL} #{parent_then_child_badges(category)}")
      end

      def has_selected_activity_category_with_parent?(category)
        has_css?(
          "#{ACTIVITY_CATEGORY_FILTER} #{category_choice_class(ACTIVITY_CATEGORY_FILTER)}[data-value='#{category.id}'] " \
            "#{parent_then_child_badges(category)}",
        )
      end

      def has_selected_whos_posting_category_with_parent?(category)
        has_css?(
          "#{WHOS_POSTING_CATEGORY_FILTER} #{category_choice_class(WHOS_POSTING_CATEGORY_FILTER)}[data-value='#{category.id}'] " \
            "#{parent_then_child_badges(category)}",
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

      private

      def category_choice_class(selector)
        find(selector).matches_css?(".d-select", wait: 0) ? ".d-select__chip" : ".selected-choice"
      end

      def parent_then_child_badges(category)
        ".badge-category__wrapper:has(.badge-category[data-category-id='#{category.parent_category_id}']) + " \
          ".badge-category__wrapper .badge-category[data-category-id='#{category.id}']"
      end
    end
  end
end
