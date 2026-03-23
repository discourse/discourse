# frozen_string_literal: true

module PageObjects
  module Pages
    class UserActivityBoosts < PageObjects::Pages::Base
      def visit(user)
        page.visit("/u/#{user.username}/activity/boosts")
        self
      end

      def visit_received(user)
        page.visit("/u/#{user.username}/notifications/boosts")
        self
      end

      def has_boost_count?(count)
        has_css?(".user-stream-item", count: count)
      end

      def has_empty_state?
        has_css?(".post-list__empty-text")
      end

      def has_boost_for_post?(post)
        has_css?(".user-stream-item a[href='#{post.url}']")
      end
    end
  end
end
