# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminCategoryManagement < AdminBase
      ROW_SELECTOR = ".admin-category-management-list__table .d-table__row"

      def visit_all
        page.visit("/admin/config/category-management/all")
      end

      def visit_support
        page.visit("/admin/config/category-management/support")
      end

      def filter_controls
        PageObjects::Components::DFilterControls.new(".d-filter-controls")
      end

      def filter_by_name(name)
        filter_controls.type_in_search(name)
      end

      def open_settings(category)
        row(category).find(".admin-category-management-list__open-settings").click
      end

      def has_category?(category)
        page.has_css?(row_selector(category))
      end

      def has_no_category?(category)
        page.has_no_css?(row_selector(category))
      end

      def has_category_details?(category, description:, visibility:, topic_count:)
        page.has_css?(category_badge_selector(category), text: category.name) &&
          page.has_css?(
            "#{row_selector(category)} .admin-category-management-list__description",
            text: description,
          ) &&
          page.has_css?(
            "#{row_selector(category)} .admin-category-management-list__visibility",
            text: visibility,
          ) &&
          page.has_css?(
            "#{row_selector(category)} .admin-category-management-list__topic-count",
            text: topic_count.to_s,
          )
      end

      def has_category_icon?(category)
        page.has_css?("#{category_badge_selector(category)} .d-icon-#{category.icon}")
      end

      def has_category_emoji?(category)
        page.has_css?("#{category_badge_selector(category)} img.emoji[title='#{category.emoji}']")
      end

      def has_open_settings_link?(category)
        page.has_css?(
          "#{row_selector(category)} .admin-category-management-list__open-settings[href='#{category.slug_url_without_id}/edit/general']",
        )
      end

      private

      def row(category)
        page.find(row_selector(category))
      end

      def row_selector(category)
        "#{ROW_SELECTOR}[data-category-id='#{category.id}']"
      end

      def category_badge_selector(category)
        "#{row_selector(category)} .admin-category-management-list__category-badges .badge-category[data-category-id='#{category.id}']"
      end
    end
  end
end
