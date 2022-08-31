# frozen_string_literal: true

module PageObjects
  module Pages
    class Topic
      include Capybara::DSL

      POST_CLASSES = {
        show_more_actions: ".show-more-actions"
      }

      POST_ACTION_BUTTON_CLASSES = {
        bookmark: ".bookmark.with-reminder"
      }

      def has_post_content?(post)
        post_by_number(post).has_content? post.raw
      end

      def has_post_more_actions?(post)
        post_by_number(post).has_css?(POST_CLASSES[:show_more_actions])
      end

      def post_bookmarked?(post)
        post_by_number(post).has_css?(POST_ACTION_BUTTON_CLASSES[:bookmark] + ".bookmarked")
      end

      def expand_post_actions(post)
        post_by_number(post).find(POST_CLASSES[:show_more_actions]).click
      end

      def click_post_action_button(post, button)
        post_by_number(post).find(POST_ACTION_BUTTON_CLASSES[button]).click
      end

      def click_topic_footer_button(button)
        find_topic_footer_button(button).click
      end

      def topic_bookmarked?
        bookmark_button = find_topic_footer_button(:bookmark)
        bookmark_button.has_content?("Edit Bookmark")
        bookmark_button.has_css?(".bookmarked")
      end

      def find_topic_footer_button(button)
        find("#topic-footer-button-#{button}")
      end

      private

      def post_by_number(post)
        find("#post_#{post.post_number}")
      end
    end
  end
end
