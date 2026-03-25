# frozen_string_literal: true

module PageObjects
  module Pages
    class UserActivityAppreciations < PageObjects::Pages::Base
      def visit_given(user)
        page.visit("/u/#{user.username}/activity/appreciations")
        self
      end

      def visit_received(user)
        page.visit("/u/#{user.username}/notifications/appreciations-received")
        self
      end

      def has_appreciation_count?(count)
        has_css?(".user-stream-item", count: count)
      end

      def has_no_appreciations?
        has_css?(".post-list__empty-text")
      end

      def has_appreciation_for_post?(post)
        has_css?(".user-stream-item a[href='#{post.url}']")
      end

      def has_appreciation_type?(type)
        has_css?(".appreciation-action--#{type}")
      end
    end
  end
end
