# frozen_string_literal: true

module PageObjects
  module Components
    class SidebarHeaderDropdown < PageObjects::Components::Base
      def click
        page.find(".hamburger-dropdown").click
        wait_for_animation(find(".menu-panel"), timeout: 5)
        self
      end

      SIDEBAR_HAMBURGER_DROPDOWN = ".sidebar-hamburger-dropdown"

      def visible?
        page.has_css?(SIDEBAR_HAMBURGER_DROPDOWN)
      end

      def hidden?
        page.has_no_css?(SIDEBAR_HAMBURGER_DROPDOWN)
      end

      def has_no_keyboard_shortcuts_button?
        page.has_no_css?(".sidebar-footer-actions-keyboard-shortcuts")
      end

      def click_categories_header_button
        page.click_button(
          I18n.t("js.sidebar.sections.categories.header_action_title"),
          class: "sidebar-section-header-button",
        )
      end

      def click_topics_link
        find(".sidebar-section-link[data-link-name='everything']").click
      end

      def click_toggle_to_desktop_view_button
        page.click_button(
          I18n.t("js.desktop_view"),
          class: "sidebar-footer-actions-toggle-mobile-view",
        )
      end

      def click_outside
        width = page.evaluate_script("document.body.clientWidth")
        page.find("body").click(x: width - 1, y: 1)
      end
    end
  end
end
