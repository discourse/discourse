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
        component.find("[data-permission]")["data-permission"]
      end

      def has_permission?(permission)
        component.has_css?("[data-permission='#{permission}']")
      end

      def has_available_permissions?(*permissions)
        menu = open_permission_menu

        within(menu.portal_with_identifier_selector) do
          has_css?(PERMISSION_OPTION_SELECTOR, count: permissions.length) &&
            permissions.all? { |permission| has_css?(permission_option_selector(permission)) }
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
        find(@selector)
      end

      def permission_menu
        PageObjects::Components::DMenu.new(
          component.find(".d-access-control__permission"),
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
