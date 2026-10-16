# frozen_string_literal: true

module PageObjects
  module Modals
    class SidebarEditNavigationModal < PageObjects::Modals::Base
      def closed?
        have_count(0).matches?(
          browser_root.locator(".sidebar__edit-navigation-menu__modal").filter(visible: true),
        )
      end

      def has_right_title?(title)
        contain_text([browser_text_pattern(title)], useInnerText: true).matches?(
          browser_root.locator(".sidebar__edit-navigation-menu__modal .d-modal__title-text").filter(
            visible: true,
          ),
        )
      end

      def has_focus_on_filter_input?
        have_count(0).does_not_match?(
          browser_root.locator(".sidebar__edit-navigation-menu__filter-input-field:focus").filter(
            visible: true,
          ),
        )
      end

      def filter(text)
        browser_root
          .locator(".sidebar__edit-navigation-menu__filter-input-field")
          .filter(visible: true)
          .fill(text)
        self
      end

      def click_reset_to_defaults_button
        browser_root
          .locator(
            "[id=#{I18n.t("js.sidebar.edit_navigation_modal_form.reset_to_defaults").to_s.to_json}], [name=#{I18n.t("js.sidebar.edit_navigation_modal_form.reset_to_defaults").to_s.to_json}]",
          )
          .or(
            browser_root.get_by_role(
              "button",
              name: I18n.t("js.sidebar.edit_navigation_modal_form.reset_to_defaults"),
            ),
          )
          .filter(visible: true)
          .click
        self
      end

      def has_no_reset_to_defaults_button?
        have_count(0).matches?(
          browser_root
            .get_by_role("button")
            .and(
              browser_root.locator(
                "[id=#{I18n.t("js.sidebar.edit_navigation_modal_form.reset_to_defaults").to_s.to_json}], [name=#{I18n.t("js.sidebar.edit_navigation_modal_form.reset_to_defaults").to_s.to_json}]",
              ).or(
                browser_root.get_by_role(
                  "button",
                  name: I18n.t("js.sidebar.edit_navigation_modal_form.reset_to_defaults"),
                ),
              ),
            )
            .filter(visible: true),
        )
      end

      def save
        browser_root
          .locator(".sidebar__edit-navigation-menu__save-button")
          .filter(visible: true)
          .click
        self
      end

      def deselect_all
        browser_root
          .locator(
            "[id=#{I18n.t("js.sidebar.edit_navigation_modal_form.deselect_button_text").to_s.to_json}], [name=#{I18n.t("js.sidebar.edit_navigation_modal_form.deselect_button_text").to_s.to_json}]",
          )
          .or(
            browser_root.get_by_role(
              "button",
              name: I18n.t("js.sidebar.edit_navigation_modal_form.deselect_button_text"),
            ),
          )
          .filter(visible: true)
          .click
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
        PageObjects::Components::SelectKit.new(
          ".sidebar__edit-navigation-menu__filter-dropdown",
        ).tap(&:is_not_disabled?)
      end
    end
  end
end
