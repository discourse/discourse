# frozen_string_literal: true

module PageObjects
  module Components
    class UserMenu < PageObjects::Components::Base
      def open
        browser_root.locator(".header-dropdown-toggle.current-user").filter(visible: true).click
        expect(
          browser_root.locator(".user-menu").filter(visible: true),
        ).not_to PlaywrightMatchers.have_count(0)
        self
      end

      def click_replies_notifications_tab
        browser_root
          .locator(
            "[id=#{"user-menu-button-replies".to_s.to_json}], [name=#{"user-menu-button-replies".to_s.to_json}]",
          )
          .or(browser_root.get_by_role("link", name: "user-menu-button-replies"))
          .filter(visible: true)
          .click
        expect(
          browser_root.locator("#quick-access-replies").filter(visible: true),
        ).not_to PlaywrightMatchers.have_count(0)
        self
      end

      def click_bookmarks_tab
        browser_root
          .locator(
            "[id=#{"user-menu-button-bookmarks".to_s.to_json}], [name=#{"user-menu-button-bookmarks".to_s.to_json}]",
          )
          .or(browser_root.get_by_role("link", name: "user-menu-button-bookmarks"))
          .filter(visible: true)
          .click
        expect(
          browser_root.locator("#quick-access-bookmarks").filter(visible: true),
        ).not_to PlaywrightMatchers.have_count(0)
        self
      end

      def click_profile_tab
        browser_root
          .locator(
            "[id=#{"user-menu-button-profile".to_s.to_json}], [name=#{"user-menu-button-profile".to_s.to_json}]",
          )
          .or(browser_root.get_by_role("link", name: "user-menu-button-profile"))
          .filter(visible: true)
          .click
        expect(
          browser_root.locator("#quick-access-profile").filter(visible: true),
        ).not_to PlaywrightMatchers.have_count(0)
        self
      end

      def click_review_queue_tab
        browser_root
          .locator(
            "[id=#{"user-menu-button-review-queue".to_s.to_json}], [name=#{"user-menu-button-review-queue".to_s.to_json}]",
          )
          .or(browser_root.get_by_role("link", name: "user-menu-button-review-queue"))
          .filter(visible: true)
          .click
        expect(
          browser_root.locator("#quick-access-review-queue").filter(visible: true),
        ).not_to PlaywrightMatchers.have_count(0)
        self
      end

      def click_reviewable(reviewable)
        browser_root
          .locator("#quick-access-review-queue a[href$='/review/#{reviewable.id}']")
          .filter(visible: true)
          .click
        self
      end

      def click_logout_button
        browser_root.locator("#quick-access-profile .logout .btn").filter(visible: true).click
        expect(
          browser_root.locator(".d-header .login-button").filter(visible: true),
        ).not_to PlaywrightMatchers.have_count(0)
        self
      end

      def click_bookmark(bookmark)
        browser_root
          .locator("#quick-access-bookmarks .bookmark a[href='#{bookmark.bookmarkable.url}']")
          .filter(visible: true)
          .click
        self
      end

      def click_notification_with_href(href_substring)
        browser_root
          .locator(".user-menu .notification a[href*='#{href_substring}']")
          .filter(visible: true)
          .click
        self
      end

      def sign_out
        open
        click_profile_tab
        click_logout_button
        self
      end

      def has_group_mentioned_notification?(topic, user_that_mentioned_group, group_mentioned)
        expect(
          browser_root
            .locator("#quick-access-replies .group-mentioned")
            .filter(visible: true)
            .inner_text
            .strip,
        ).to eq("#{user_that_mentioned_group.username} @#{group_mentioned.name}\n#{topic.title}")
      end

      def has_user_full_name_mentioned_notification?(topic, user_that_mentioned)
        expect(
          browser_root
            .locator("#quick-access-replies .mentioned")
            .filter(visible: true)
            .inner_text
            .strip,
        ).to eq("#{user_that_mentioned.name}\n#{topic.title}")
      end

      def has_user_full_name_messaged_notification?(post, user)
        expect(
          browser_root
            .locator("#quick-access-all-notifications .private-message")
            .filter(visible: true)
            .inner_text
            .strip,
        ).to eq("#{user.name}\n#{post.topic.title}")
      end

      def has_user_full_name_bookmarked_notification?(post, user)
        expect(
          browser_root
            .locator("#quick-access-bookmarks .bookmark")
            .filter(visible: true)
            .inner_text
            .strip,
        ).to eq("#{user.name}\n#{post.topic.title}")
      end

      def has_user_username_mentioned_notification?(topic, user_that_mentioned)
        expect(
          browser_root
            .locator("#quick-access-replies .mentioned")
            .filter(visible: true)
            .inner_text
            .strip,
        ).to eq("#{user_that_mentioned.username}\n#{topic.title}")
      end

      def has_right_replies_button_count?(count)
        expect(
          browser_root.locator("#user-menu-button-replies").filter(visible: true).inner_text.strip,
        ).to eq(count.to_s)
      end

      def has_notification_count_of?(count)
        PlaywrightMatchers.have_count(count).matches?(
          browser_root.locator(".user-menu li.notification").filter(visible: true),
        )
      end

      def has_bookmark_count_of?(count)
        PlaywrightMatchers.have_count(count).matches?(
          browser_root.locator(".user-menu #quick-access-bookmarks li.bookmark").filter(
            visible: true,
          ),
        )
      end
    end
  end
end
