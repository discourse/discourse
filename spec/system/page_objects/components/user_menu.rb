# frozen_string_literal: true

module PageObjects
  module Components
    class UserMenu < PageObjects::Components::Base
      def open
        find(".header-dropdown-toggle.current-user").click
        has_css?(".user-menu")
        self
      end

      def click_replies_notifications_tab
        click_link("user-menu-button-replies")
        has_css?("#quick-access-replies")
        self
      end

      def click_bookmarks_tab
        click_link("user-menu-button-bookmarks")
        has_css?("#quick-access-bookmarks")
        self
      end

      def click_profile_tab
        click_link("user-menu-button-profile")
        has_css?("#quick-access-profile")
        self
      end

      def click_logout_button
        find("#quick-access-profile .logout .btn").click
        has_css?(".d-header .login-button")
        self
      end

      def click_bookmark(bookmark)
        find("#quick-access-bookmarks .bookmark a[href='#{bookmark.bookmarkable.url}']").click
        self
      end

      def sign_out
        open
        click_profile_tab
        click_logout_button
        self
      end

      def has_group_mentioned_notification?(topic, user_that_mentioned_group, group_mentioned)
        expect(find("#quick-access-replies .group-mentioned").text).to eq(
          "#{user_that_mentioned_group.username} @#{group_mentioned.name} #{topic.title}",
        )
      end

      def has_user_full_name_mentioned_notification?(topic, user_that_mentioned)
        expect(find("#quick-access-replies .mentioned").text).to eq(
          "#{user_that_mentioned.name} #{topic.title}",
        )
      end

      def has_user_full_name_messaged_notification?(post, user)
        expect(find("#quick-access-all-notifications .private-message").text).to eq(
          "#{user.name} #{post.topic.title}")
      end


      def has_user_full_name_bookmarked_notification?(topic, user)
        expect(find("#quick-access-bookmarks .bookmark").text).to eq(
         "#{user.name} #{topic.title}")

      end

      def has_user_username_mentioned_notification?(topic, user_that_mentioned)
        expect(find("#quick-access-replies .mentioned").text).to eq(
          "#{user_that_mentioned.username} #{topic.title}",
        )
      end

      def has_right_replies_button_count?(count)
        expect(find("#user-menu-button-replies").text).to eq(count.to_s)
      end

      def has_notification_count_of?(count)
        page.has_css?(".user-menu li.notification", count: count)
      end

      def has_bookmark_count_of?(count)
        page.has_css?(".user-menu #quick-access-bookmarks li.bookmark", count: count)
      end
    end
  end
end
