# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminUserBadges < PageObjects::Pages::Base
      def visit_page(user)
        page.visit "/admin/users/#{user.id}/#{user.username}/badges"
        self
      end

      def user_badges_table
        page.find(:table, id: "user-badges", visible: true)
      end

      def find_badge_row_by_granter(granter)
        user_badges_table.find(:table_row, { "Granted By" => "#{granter.username}" })
      end

      def badge_select
        PageObjects::Components::UiKit::DSelect.by_identifier("admin-user-badges-grant")
      end

      def has_grantable_badge?(name)
        if SiteSetting.enable_new_select_controls
          badge_select.open
          return badge_select.has_option_name?(name)
        end

        badge_dropdown = PageObjects::Components::SelectKit.new(".user-badges .combo-box")
        badge_dropdown.expand
        has_css?(".select-kit-row[data-name='#{name}']")
      end

      def grant_badge(name)
        if SiteSetting.enable_new_select_controls
          badge_select.select_name(name)
        else
          badge_dropdown = PageObjects::Components::SelectKit.new(".user-badges .combo-box")
          badge_dropdown.expand
          badge_dropdown.select_row_by_name(name)
        end
        page.find(".user-badges .btn-primary").click
        self
      end
    end
  end
end
