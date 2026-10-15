# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminUserBadges < PageObjects::Pages::Base
      def visit_page(user)
        browser_page
          .goto("/admin/users/#{user.id}/#{user.username}/badges")
          .tap { SystemBrowserBootstrap.wait_for(browser_page) }
        self
      end

      def user_badges_table
        browser_root.locator("table#user-badges").filter(visible: true)
      end

      def find_badge_row_by_granter(granter)
        user_badges_table.get_by_role("row").filter(
          has:
            browser_page.locator("td:nth-child(2)").filter(
              hasText: /^\s*#{Regexp.escape(granter.username)}\s*$/,
            ),
        )
      end
    end
  end
end
