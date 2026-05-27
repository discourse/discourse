# frozen_string_literal: true

require_relative "sidebar_edit_navigation_modal"

module PageObjects
  module Modals
    class SidebarEditCategories < SidebarEditNavigationModal
      def filter(text)
        super
        has_css?(".sidebar-categories-form.--filtered")
        self
      end

      def has_parent_category_color?(category)
        has_css?(
          ".sidebar-categories-form .sidebar-categories-form__row",
          style: "border-left-color: ##{category.color} ",
        )
      end

      def has_category_description_excerpt?(category)
        has_css?(
          ".sidebar-categories-form .sidebar-categories-form__category-row",
          text: category.description_excerpt,
        )
      end

      def has_no_categories?
        has_no_css?(".sidebar-categories-form .sidebar-categories-form__category-row") &&
          has_css?(
            ".sidebar-categories-form .sidebar-categories-form__no-categories",
            text: I18n.t("js.sidebar.categories_form_modal.no_categories"),
          )
      end

      def has_categories?(categories)
        has_css?(".sidebar-categories-form", text: categories.map(&:name).join("\n"))
      end

      def toggle_category_checkbox(category)
        find(
          ".sidebar-categories-form .sidebar-categories-form__category-row[data-category-id='#{category.id}'] .sidebar-categories-form__input",
        ).click

        self
      end

      def has_checkbox?(category, disabled: false)
        has_selector?(
          ".sidebar-categories-form .sidebar-categories-form__category-row[data-category-id='#{category.id}'] .sidebar-categories-form__input#{disabled ? "[disabled]" : ""}",
        )
      end

      def has_category_row?(category)
        has_css?(".sidebar-categories-form__category-row[data-category-id='#{category.id}']")
      end

      def has_no_category_row?(category)
        has_no_css?(".sidebar-categories-form__category-row[data-category-id='#{category.id}']")
      end

      def has_no_show_more_button?(category)
        has_no_css?(
          ".sidebar-categories-form__category-row[data-test-category-id='#{category.id}'] .sidebar-categories-form__show-more-btn",
        )
      end

      def has_show_more_button?(category)
        has_css?(
          ".sidebar-categories-form__category-row[data-test-category-id='#{category.id}'] .sidebar-categories-form__show-more-btn",
        )
      end

      def scroll_to_category(category)
        scroll_to(find(".sidebar-categories-form__category-row[data-category-id='#{category.id}']"))
        self
      end

      def click_show_more_button(category)
        find(
          ".sidebar-categories-form__category-row[data-test-category-id='#{category.id}'] .sidebar-categories-form__show-more-btn",
        ).click
        self
      end

      def has_tag_in_description?(category)
        has_css?(
          ".sidebar-categories-form__category-row[data-category-id='#{category.id}'] .sidebar-categories-form__category-description a.hashtag-cooked[data-type='tag']",
        )
      end

      def has_icon_in_description?(category)
        has_css?(
          ".sidebar-categories-form__category-row[data-category-id='#{category.id}'] .sidebar-categories-form__category-description a.hashtag-cooked .hashtag-category-icon",
        )
      end

      def has_emoji_in_description?(category)
        has_css?(
          ".sidebar-categories-form__category-row[data-category-id='#{category.id}'] .sidebar-categories-form__category-description a.hashtag-cooked .hashtag-category-emoji",
        )
      end
    end
  end
end
