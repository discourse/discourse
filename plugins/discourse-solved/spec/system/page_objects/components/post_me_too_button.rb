# frozen_string_literal: true

module PageObjects
  module Components
    class PostMeTooButton < PageObjects::Components::Base
      SELECTOR = ".post-action-menu__solved-me-too"

      def initialize(post)
        @post = post
      end

      def click
        within_post { find(SELECTOR).click }
        self
      end

      def has_me_too_button?
        within_post { has_css?(SELECTOR) }
      end

      def has_no_me_too_button?
        within_post { has_no_css?(SELECTOR) }
      end

      def has_active?
        within_post { has_css?("#{SELECTOR}.has-me-too") }
      end

      def has_count?(count)
        within_post { has_css?(SELECTOR, text: "Me too (#{count})") }
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
