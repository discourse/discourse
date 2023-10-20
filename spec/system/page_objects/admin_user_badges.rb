# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminUserBadges < PageObjects::Pages::Base
      def visit_page(user)
        page.visit "/admin/users/#{user.id}/#{user.username}/badges"
        self
      end

      def find_badge_row_by_granter(granter)
        page.find(:table_row, { "Granted By" => "#{granter.username}" })
      end
    end
  end
end
