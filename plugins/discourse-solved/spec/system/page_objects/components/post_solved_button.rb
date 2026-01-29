# frozen_string_literal: true

module PageObjects
  module Components
    class PostSolvedButton < PageObjects::Components::Base
      def initialize(post)
        @post = post
      end

      def accept_answer
        within_post { find(".post-action-menu__solved-unaccepted").click }
        self
      end

      def has_accept_button?
        within_post { has_css?(".post-action-menu__solved-unaccepted") }
      end

      def has_no_accept_button?
        within_post { has_no_css?(".post-action-menu__solved-unaccepted") }
      end

      def has_accepted_button?
        within_post { has_css?(".post-action-menu__solved-accepted") }
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
