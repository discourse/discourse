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
    end
  end
end
