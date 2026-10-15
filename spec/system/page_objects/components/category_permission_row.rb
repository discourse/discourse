# frozen_string_literal: true

module PageObjects
  module Components
    class CategoryPermissionRow < PageObjects::Components::Base
      def group_permission_row_selector(group_name)
        ".permission-row[data-group-name='#{group_name}']"
      end

      def has_group_permission?(group_name, permissions = nil)
        if !permissions
          PlaywrightMatchers.have_count(0).does_not_match?(
            browser_root.locator(group_permission_row_selector(group_name)).filter(visible: true),
          )
        else
          permissions.each do |permission|
            PlaywrightMatchers.have_count(0).does_not_match?(
              browser_root.locator(
                "#{group_permission_row_selector(group_name)} .#{permission}-granted",
              ).filter(visible: true),
            )
          end
        end
      end

      def has_no_group_permission?(group_name)
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(group_permission_row_selector(group_name)).filter(visible: true),
        )
      end

      def navigate_to_group(group_name)
        browser_root
          .locator(group_permission_row_selector(group_name))
          .filter(visible: true)
          .locator(".group-name-link")
          .filter(visible: true)
          .click
      end

      def remove_group_permission(group_name)
        browser_root
          .locator(group_permission_row_selector(group_name))
          .filter(visible: true)
          .locator(".remove-permission")
          .filter(visible: true)
          .click
      end

      def toggle_group_permission(group_name, permission)
        browser_root
          .locator(group_permission_row_selector(group_name))
          .filter(visible: true)
          .locator(".#{permission}-toggle")
          .filter(visible: true)
          .click
      end
    end
  end
end
