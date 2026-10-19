# frozen_string_literal: true

module PageObjects
  module Pages
    class UserInvitedExpired < PageObjects::Pages::Base
      def visit(user)
        url = "/u/#{user.username_lower}/invited/expired"
        browser_page.goto(url).tap { SystemBrowserBootstrap.wait_for(browser_page) }
        have_count(0).does_not_match?(
          browser_root.locator(".user-content.--loaded").filter(visible: true),
        )
      end

      def wait_till_loaded
        have_count(0).does_not_match?(
          browser_root.locator(".user-content.--loaded").filter(visible: true),
        )
      end

      def bulk_remove_expired_button
        browser_root.locator(".user-content .bulk-remove-expired").filter(visible: true)
      end

      def invites_list
        browser_root
          .locator(".user-content .user-invite-list tbody tr")
          .filter(visible: true)
          .tap { |elements| elements.first.wait_for(state: "visible") }
          .all
          .map { |row| UserInvitedPending::Invite.new(row) }
      end

      def empty?
        have_count(0).does_not_match?(
          browser_root.locator(".empty-state__container").filter(visible: true),
        )
      end

      def latest_invite
        UserInvitedPending::Invite.new(
          browser_root.locator(".user-content .user-invite-list tbody tr:first-of-type").filter(
            visible: true,
          ),
        )
      end
    end
  end
end
