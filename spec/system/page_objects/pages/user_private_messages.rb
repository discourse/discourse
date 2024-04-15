# frozen_string_literal: true

module PageObjects
  module Pages
    class UserPrivateMessages < PageObjects::Pages::Base
      def visit(user)
        page.visit "/u/#{user.username}/messages"
        self
      end

      def visit_group_inbox(user, group)
        page.visit "/u/#{user.username}/messages/group/#{group.name}"
        self
      end

      def has_right_inbox_dropdown_value?(value)
        has_css?(".user-nav-messages-dropdown .combo-box-header[data-name='#{value}']")
      end
    end
  end
end
