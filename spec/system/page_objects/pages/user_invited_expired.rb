# frozen_string_literal: true

module PageObjects
  module Pages
    class UserInvitedExpired < PageObjects::Pages::Base
      def visit(user)
        url = "/u/#{user.username_lower}/invited/expired"
        page.visit(url)
        has_css?(".user-content.--loaded")
      end

      def wait_till_loaded
        has_css?(".user-content.--loaded")
      end

      def bulk_remove_expired_button
        find(".user-content .bulk-remove-expired")
      end

      def invites_list
        all(".user-content .user-invite-list tbody tr").map do |row|
          UserInvitedPending::Invite.new(row)
        end
      end

      def empty?
        has_css?(".empty-state__container")
      end

      def latest_invite
        UserInvitedPending::Invite.new(
          find(".user-content .user-invite-list tbody tr:first-of-type"),
        )
      end
    end
  end
end
