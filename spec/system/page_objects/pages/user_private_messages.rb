# frozen_string_literal: true

module PageObjects
  module Pages
    class UserPrivateMessages < PageObjects::Pages::Base
      def visit(user)
        browser_page
          .goto("/u/#{user.username}/messages")
          .tap { SystemBrowserBootstrap.wait_for(browser_page) }
        self
      end

      def visit_group_inbox(user, group)
        browser_page
          .goto("/u/#{user.username}/messages/group/#{group.name}")
          .tap { SystemBrowserBootstrap.wait_for(browser_page) }
        self
      end

      def inbox_dropdown
        PageObjects::Components::DMenu.new(
          browser_root.locator(".messages-dropdown-trigger").filter(visible: true),
        )
      end

      def has_right_inbox_dropdown_value?(value)
        inbox_dropdown.has_value?(value)
        inbox_dropdown.expand
        inbox_dropdown.has_option?(".dropdown-menu__item", value)
      end

      def has_unread_icon_in_inbox_dropdown?
        expect(inbox_dropdown.locator(".d-icon-d-unread").filter(visible: true)).not_to have_count(
          0,
        )
        inbox_dropdown.expand
        have_count(0).does_not_match?(
          inbox_dropdown
            .option(".dropdown-menu__item", :first)
            .locator(".d-icon-d-unread")
            .filter(visible: true),
        )
      end

      def has_unread_count_in_inbox_dropdown?(count)
        inbox_dropdown.has_value?(count)
        inbox_dropdown.expand
        inbox_dropdown.has_option?(".dropdown-menu__item", count)
      end

      def click_unseen_private_message(topic_id)
        browser_root
          .locator("tr[data-topic-id='#{topic_id}'] a[data-topic-id='#{topic_id}']")
          .filter(visible: true)
          .click
      end
    end
  end
end
