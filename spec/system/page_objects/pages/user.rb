# frozen_string_literal: true

module PageObjects
  module Pages
    class User < PageObjects::Pages::Base
      def visit(user)
        page.visit("/u/#{user.username}")
        self
      end

      def find(selector)
        page.find(".new-user-wrapper #{selector}")
      end

      def active_user_primary_navigation
        find(".user-navigation-primary li a.active")
      end

      def active_user_secondary_navigation
        find(".user-navigation-secondary li a.active")
      end

      def has_warning_messages_path?(user)
        page.has_current_path?("/u/#{user.username}/messages/warnings")
      end

      def click_staff_info_warnings_link(user, warnings_count: 0)
        staff_counters = page.find(".staff-counters")
        staff_counters.find("a[href='/u/#{user.username}/messages/warnings']").click
        self
      end

      def expand_info_panel
        button = page.find("button[aria-controls='collapsed-info-panel']")
        button.click if button["aria-expanded"] == "false"
        self
      end

      def has_reviewable_flagged_posts_path?(user)
        params = {
          status: "approved",
          sort_order: "score",
          type: "ReviewableFlaggedPost",
          username: user.username,
        }
        page.has_current_path?("/review?#{params.to_query}")
      end

      def staff_info_flagged_posts_counter
        page.find(".staff-counters .flagged-posts")
      end

      def has_staff_info_flagged_posts_count?(count:)
        staff_info_flagged_posts_counter.text.to_i == count
      end

      def has_no_staff_info_flagged_posts_counter?
        page.has_no_css?(".staff-counters .flagged-posts")
      end
    end
  end
end
