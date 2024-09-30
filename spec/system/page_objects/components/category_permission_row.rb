# frozen_string_literal: true

module PageObjects
  module Components
    class CategoryPermissionRow < PageObjects::Components::Base
      def group_permission_row_selector(group_name)
        ".permission-row[data-group-name='#{group_name}']"
      end

      def has_group_permission?(group_name, permissions = nil)
        if !permissions
          page.has_css?(group_permission_row_selector(group_name))
        else
          permissions.each do |permission|
            page.has_css?("#{group_permission_row_selector(group_name)} .#{permission}-granted")
          end
        end
      end

      def has_no_group_permission?(group_name)
        page.has_no_css?(group_permission_row_selector(group_name))
      end

      def navigate_to_group(group_name)
        find(group_permission_row_selector(group_name)).find(".group-name-link").click
      end

      def remove_group_permission(group_name)
        find(group_permission_row_selector(group_name)).find(".remove-permission").click
      end

      def toggle_group_permission(group_name, permission)
        find(group_permission_row_selector(group_name)).find(".#{permission}-toggle").click
      end
    end
  end
end
