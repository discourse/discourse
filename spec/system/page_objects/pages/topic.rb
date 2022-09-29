# frozen_string_literal: true

module PageObjects
  module Pages
    class Topic < PageObjects::Pages::Base
      def initialize
        setup_component_classes!(
          post_show_more_actions: ".show-more-actions",
          post_action_button_bookmark: ".bookmark.with-reminder"
        )
      end

      def has_post_content?(post)
        post_by_number(post).has_content? post.raw
      end

      def has_post_more_actions?(post)
        within post_by_number(post) do
          has_css?(@component_classes[:post_show_more_actions])
        end
      end

      def has_post_bookmarked?(post)
        within post_by_number(post) do
          has_css?(@component_classes[:post_action_button_bookmark] + ".bookmarked")
        end
      end

      def expand_post_actions(post)
        post_by_number(post).find(@component_classes[:post_show_more_actions]).click
      end

      def click_post_action_button(post, button)
        post_by_number(post).find(@component_classes["post_action_button_#{button}".to_sym]).click
      end

      def click_topic_footer_button(button)
        find_topic_footer_button(button).click
      end

      def has_topic_bookmarked?
        has_css?("#{topic_footer_button_id("bookmark")}.bookmarked", text: "Edit Bookmark")
      end

      def find_topic_footer_button(button)
        find(topic_footer_button_id(button))
      end

      private

      def topic_footer_button_id(button)
        "#topic-footer-button-#{button}"
      end

      def post_by_number(post)
        find("#post_#{post.post_number}")
      end
    end
  end
end
