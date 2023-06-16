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

      def staff_info_section
        begin
          page.find(".staff-counters")
        rescue Capybara::ElementNotFound
          nil
        end
      end

      def click_staff_info_warnings_link(user, warnings_count: 0)
        staff_info_section.find("a[href='/u/#{user.username}/messages/warnings']").click
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
        staff_info_section&.find(".flagged-posts")
      end
    end
  end
end
