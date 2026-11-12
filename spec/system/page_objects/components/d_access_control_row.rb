# frozen_string_literal: true

module PageObjects
  module Components
    class DAccessControlRow < PageObjects::Components::Base
      OPTION_SELECTOR = "[role='option']"

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
        list = open_permission_list

        list.has_css?(OPTION_SELECTOR, count: permissions.length) &&
          permissions.all? { |permission| list.has_css?(option_selector(permission)) }
      end

      def has_available_permission?(permission)
        open_permission_list.has_css?(option_selector(permission))
      end

      def has_no_available_permission?(permission)
        open_permission_list.has_no_css?(option_selector(permission))
      end

      def select_permission(permission)
        open_permission_list.find(option_selector(permission)).click
      end

      private

      def component
        find(@selector)
      end

      def open_permission_list
        select = component.find(".d-access-control__permission")
        select.click if select["aria-expanded"] != "true"
        # The list is portaled, so it is found through the id the open select points at.
        listbox_id =
          component.find(".d-access-control__permission[aria-expanded='true']")["aria-controls"]
        find("[id='#{listbox_id}']")
      end

      def option_selector(permission)
        "#{OPTION_SELECTOR}[data-value='#{permission}']"
      end
    end
  end
end
