# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminCategoryManagement < AdminBase
      ROW_SELECTOR = ".admin-category-management-list__table .d-table__row"

      def visit_all
        browser_page
          .goto("/admin/config/category-management/all")
          .tap { SystemBrowserBootstrap.wait_for(browser_page) }
      end

      def visit_support
        browser_page
          .goto("/admin/config/category-management/support")
          .tap { SystemBrowserBootstrap.wait_for(browser_page) }
      end

      def filter_controls
        PageObjects::Components::DFilterControls.new(".d-filter-controls")
      end

      def filter_by_name(name)
        filter_controls.type_in_search(name)
      end

      def open_settings(category)
        row(category)
          .locator(".admin-category-management-list__open-settings")
          .filter(visible: true)
          .click
      end

      def has_category?(category)
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(row_selector(category)).filter(visible: true),
        )
      end

      def has_no_category?(category)
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(row_selector(category)).filter(visible: true),
        )
      end

      def has_category_details?(category, description:, visibility:, topic_count:)
        PlaywrightMatchers.contain_text(
          [browser_text_pattern(category.name)],
          useInnerText: true,
        ).matches?(browser_root.locator(category_badge_selector(category)).filter(visible: true)) &&
          PlaywrightMatchers.contain_text(
            [browser_text_pattern(description)],
            useInnerText: true,
          ).matches?(
            browser_root.locator(
              "#{row_selector(category)} .admin-category-management-list__description",
            ).filter(visible: true),
          ) &&
          PlaywrightMatchers.contain_text(
            [browser_text_pattern(visibility)],
            useInnerText: true,
          ).matches?(
            browser_root.locator(
              "#{row_selector(category)} .admin-category-management-list__visibility",
            ).filter(visible: true),
          ) &&
          PlaywrightMatchers.contain_text(
            [browser_text_pattern(topic_count.to_s)],
            useInnerText: true,
          ).matches?(
            browser_root.locator(
              "#{row_selector(category)} .admin-category-management-list__topic-count",
            ).filter(visible: true),
          )
      end

      def has_category_icon?(category)
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(
            "#{category_badge_selector(category)} .d-icon-#{category.icon}",
          ).filter(visible: true),
        )
      end

      def has_category_emoji?(category)
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(
            "#{category_badge_selector(category)} img.emoji[title='#{category.emoji}']",
          ).filter(visible: true),
        )
      end

      def has_open_settings_link?(category)
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(
            "#{row_selector(category)} .admin-category-management-list__open-settings[href='#{category.slug_url_without_id}/edit/general']",
          ).filter(visible: true),
        )
      end

      private

      def row(category)
        browser_root.locator(row_selector(category)).filter(visible: true)
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
