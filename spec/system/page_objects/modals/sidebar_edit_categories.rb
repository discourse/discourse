# frozen_string_literal: true

module PageObjects
  module Modals
    class SidebarEditCategories < PageObjects::Modals::Base
      MODAL_SELECTOR = ".sidebar-categories-form-modal"

      def closed?
        has_no_css?(MODAL_SELECTOR)
      end

      def has_right_title?(title)
        has_css?("#{MODAL_SELECTOR} #discourse-modal-title", text: title)
      end

      def toggle_category_checkbox(category)
        find(
          "#{MODAL_SELECTOR} .sidebar-categories-form__category-row[data-category-id='#{category.id}'] .sidebar-categories-form__input",
        ).click

        self
      end

      def save
        find("#{MODAL_SELECTOR} .sidebar-categories-form__save-button").click
      end
    end
  end
end
