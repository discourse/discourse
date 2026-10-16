# frozen_string_literal: true

module PageObjects
  module Components
    class DAccessControlRow < PageObjects::Components::Base
      PERMISSION_MENU_IDENTIFIER = "d-access-control__permission-menu"
      PERMISSION_OPTION_SELECTOR = ".d-access-control__permission-option"

      def initialize(selector)
        @selector = selector
      end

      def permission
        component
          .locator("[data-permission]")
          .filter(visible: true)
          .get_attribute("data-permission")
      end

      def has_permission?(permission)
        have_count(0).does_not_match?(
          component.locator("[data-permission='#{permission}']").filter(visible: true),
        )
      end

      def has_available_permissions?(*permissions)
        menu = open_permission_menu

        within_browser(menu.portal_with_identifier_selector) do
          have_count(permissions.length).matches?(
            browser_root.locator(PERMISSION_OPTION_SELECTOR).filter(visible: true),
          ) &&
            permissions.all? do |permission|
              have_count(0).does_not_match?(
                browser_root.locator(permission_option_selector(permission)).filter(visible: true),
              )
            end
        end
      end

      def has_available_permission?(permission)
        open_permission_menu.has_option?(permission_option_selector(permission))
      end

      def has_no_available_permission?(permission)
        open_permission_menu.has_no_option?(permission_option_selector(permission))
      end

      def select_permission(permission)
        open_permission_menu.option(permission_option_selector(permission)).click
      end

      private

      def component
        browser_root.locator(@selector).filter(visible: true)
      end

      def permission_menu
        PageObjects::Components::DMenu.new(
          component.locator(".d-access-control__permission").filter(visible: true),
          PERMISSION_MENU_IDENTIFIER,
        )
      end

      def open_permission_menu
        menu = permission_menu
        menu.expand if menu.is_collapsed?
        menu
      end

      def permission_option_selector(permission)
        "#{PERMISSION_OPTION_SELECTOR}[data-permission-id='#{permission}']"
      end
    end
  end
end
