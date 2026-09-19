# frozen_string_literal: true

module PageObjects
  module Components
    class PostSharedIssueButton < PageObjects::Components::Base
      SELECTOR = ".post-action-menu__solved-shared-issue"

      def initialize(post)
        @post = post
      end

      def click
        within_post { find(SELECTOR).click }
        self
      end

      def has_shared_issue_button?
        within_post { has_css?(SELECTOR) }
      end

      def has_no_shared_issue_button?
        within_post { has_no_css?(SELECTOR) }
      end

      def has_active?
        within_post { has_css?("#{SELECTOR}.has-shared-issue") }
      end

      def has_read_only?
        within_post { has_css?("#{SELECTOR}.disabled") }
      end

      def has_count?(count)
        label = count.zero? ? "Me too" : "Me too (#{count})"
        within_post { has_css?(SELECTOR, exact_text: label) }
      end

      private

      def within_post
        within(post_selector) { yield }
      end

      def post_selector
        "#post_#{@post.post_number}"
      end
    end
  end
end
