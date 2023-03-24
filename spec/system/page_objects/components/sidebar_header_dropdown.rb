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

      def click_community_header_button
        page.click_button(
          I18n.t("js.sidebar.sections.community.header_action_title"),
          class: "sidebar-section-header-button",
        )
      end

      def click_everything_link
        page.click_link(
          I18n.t("js.sidebar.sections.community.links.everything.content"),
          class: "sidebar-section-link-everything",
        )
      end

      def click_toggle_to_desktop_view_button
        page.click_button(
          I18n.t("js.desktop_view"),
          class: "sidebar-footer-actions-toggle-mobile-view",
        )
      end

      def click_outside
        dropdown = page.find(SIDEBAR_HAMBURGER_DROPDOWN)
        dropdown.click(x: dropdown.rect.width + 1, y: 1)
      end
    end
  end
end
