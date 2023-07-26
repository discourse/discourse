# frozen_string_literal: true

module PageObjects
  module Modals
    class SidebarEditNavigationModal < PageObjects::Modals::Base
      def closed?
        has_no_css?(".sidebar__edit-navigation-menu__modal")
      end

      def has_right_title?(title)
        has_css?(".sidebar__edit-navigation-menu__modal .title", text: title)
      end

      def has_focus_on_filter_input?
        evaluate_script("document.activeElement").native ==
          find(".sidebar__edit-navigation-menu__filter-input-field").native
      end

      def filter(text)
        find(".sidebar__edit-navigation-menu__filter-input-field").fill_in(with: text)
        self
      end

      def click_reset_to_defaults_button
        click_button(I18n.t("js.sidebar.edit_navigation_modal_form.reset_to_defaults"))
        self
      end

      def has_no_reset_to_defaults_button?
        has_no_button?(I18n.t("js.sidebar.edit_navigation_modal_form.reset_to_defaults"))
      end

      def save
        find(".sidebar__edit-navigation-menu__save-button").click
        self
      end

      def deselect_all
        click_button(I18n.t("js.sidebar.edit_navigation_modal_form.deselect_button_text"))
        self
      end

      def filter_by_selected
        dropdown_filter.select_row_by_name(
          I18n.t("js.sidebar.edit_navigation_modal_form.filter_dropdown.selected"),
        )

        self
      end

      def filter_by_unselected
        dropdown_filter.select_row_by_name(
          I18n.t("js.sidebar.edit_navigation_modal_form.filter_dropdown.unselected"),
        )

        self
      end

      def filter_by_all
        dropdown_filter.select_row_by_name(
          I18n.t("js.sidebar.edit_navigation_modal_form.filter_dropdown.all"),
        )

        self
      end

      private

      def dropdown_filter
        PageObjects::Components::SelectKit.new(".sidebar__edit-navigation-menu__filter-dropdown")
      end
    end
  end
end
