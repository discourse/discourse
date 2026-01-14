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

      def inbox_dropdown
        PageObjects::Components::DMenu.new(find(".messages-dropdown-trigger"))
      end

      def has_right_inbox_dropdown_value?(value)
        inbox_dropdown.has_value?(value)
        inbox_dropdown.expand
        inbox_dropdown.has_option?(".dropdown-menu__item", value)
      end

      def has_unread_icon_in_inbox_dropdown?
        inbox_dropdown.has_css?(".d-icon-d-unread")
        inbox_dropdown.expand
        inbox_dropdown.option(".dropdown-menu__item", :first).has_css?(".d-icon-d-unread")
      end

      def has_unread_count_in_inbox_dropdown?(count)
        inbox_dropdown.has_value?(count)
        inbox_dropdown.expand
        inbox_dropdown.has_option?(".dropdown-menu__item", count)
      end

      def click_unseen_private_mesage(topic_id)
        find("tr[data-topic-id='#{topic_id}'] a[data-topic-id='#{topic_id}']").click
      end
    end
  end
end
