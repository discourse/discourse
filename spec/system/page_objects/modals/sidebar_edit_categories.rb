# frozen_string_literal: true

require_relative "sidebar_edit_navigation_modal"

module PageObjects
  module Modals
    class SidebarEditCategories < SidebarEditNavigationModal
      def has_parent_category_color?(category)
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(
            ".sidebar-categories-form .sidebar-categories-form__row[style=#{"border-left-color: ##{category.color} ".to_json}]",
          ).filter(visible: true),
        )
      end

      def has_category_description_excerpt?(category)
        PlaywrightMatchers.contain_text(
          [browser_text_pattern(category.description_excerpt)],
          useInnerText: true,
        ).matches?(
          browser_root.locator(
            ".sidebar-categories-form .sidebar-categories-form__category-row",
          ).filter(visible: true),
        )
      end

      def has_no_categories?
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(
            ".sidebar-categories-form .sidebar-categories-form__category-row",
          ).filter(visible: true),
        ) &&
          PlaywrightMatchers.contain_text(
            [browser_text_pattern(I18n.t("js.sidebar.categories_form_modal.no_categories"))],
            useInnerText: true,
          ).matches?(
            browser_root.locator(
              ".sidebar-categories-form .sidebar-categories-form__no-categories",
            ).filter(visible: true),
          )
      end

      def has_categories?(categories)
        PlaywrightMatchers.contain_text(
          [browser_text_pattern(categories.map(&:name).join("\n"))],
          useInnerText: true,
        ).matches?(browser_root.locator(".sidebar-categories-form").filter(visible: true))
      end

      def toggle_category_checkbox(category)
        browser_root
          .locator(
            ".sidebar-categories-form .sidebar-categories-form__category-row[data-category-id='#{category.id}'] .sidebar-categories-form__input",
          )
          .filter(visible: true)
          .click

        self
      end

      def has_checkbox?(category, disabled: false)
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(
            ".sidebar-categories-form .sidebar-categories-form__category-row[data-category-id='#{category.id}'] .sidebar-categories-form__input#{disabled ? "[disabled]" : ""}",
          ).filter(visible: true),
        )
      end

      def has_category_row?(category)
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(
            ".sidebar-categories-form__category-row[data-category-id='#{category.id}']",
          ).filter(visible: true),
        )
      end

      def has_no_category_row?(category)
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(
            ".sidebar-categories-form__category-row[data-category-id='#{category.id}']",
          ).filter(visible: true),
        )
      end

      def has_no_show_more_button?(category)
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(
            ".sidebar-categories-form__category-row[data-test-category-id='#{category.id}'] .sidebar-categories-form__show-more-btn",
          ).filter(visible: true),
        )
      end

      def has_show_more_button?(category)
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(
            ".sidebar-categories-form__category-row[data-test-category-id='#{category.id}'] .sidebar-categories-form__show-more-btn",
          ).filter(visible: true),
        )
      end

      def scroll_to_category(category)
        browser_root
          .locator(".sidebar-categories-form__category-row[data-category-id='#{category.id}']")
          .filter(visible: true)
          .evaluate("element => element.scrollIntoView({block: 'center'})")
        self
      end

      def click_show_more_button(category)
        browser_root
          .locator(
            ".sidebar-categories-form__category-row[data-test-category-id='#{category.id}'] .sidebar-categories-form__show-more-btn",
          )
          .filter(visible: true)
          .click
        self
      end

      def has_tag_in_description?(category)
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(
            ".sidebar-categories-form__category-row[data-category-id='#{category.id}'] .sidebar-categories-form__category-description a.hashtag-cooked[data-type='tag']",
          ).filter(visible: true),
        )
      end

      def has_icon_in_description?(category)
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(
            ".sidebar-categories-form__category-row[data-category-id='#{category.id}'] .sidebar-categories-form__category-description a.hashtag-cooked .hashtag-category-icon",
          ).filter(visible: true),
        )
      end

      def has_emoji_in_description?(category)
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(
            ".sidebar-categories-form__category-row[data-category-id='#{category.id}'] .sidebar-categories-form__category-description a.hashtag-cooked .hashtag-category-emoji",
          ).filter(visible: true),
        )
      end
    end
  end
end
