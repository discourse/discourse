# frozen_string_literal: true

require_relative "sidebar_edit_navigation_modal"

module PageObjects
  module Modals
    class SidebarEditCategories < SidebarEditNavigationModal
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
        category_names = categories.map(&:name)

        categories =
          all(
            ".sidebar-categories-form .sidebar-categories-form__category-row",
            count: category_names.length,
          )

        expect(categories.map(&:text)).to eq(category_names)
      end

      def has_checkbox?(category, disabled: false)
        has_selector?(
          ".sidebar-categories-form .sidebar-categories-form__category-row[data-category-id='#{category.id}'] .sidebar-categories-form__input#{disabled ? "[disabled]" : ""}",
        )
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
    end
  end
end
