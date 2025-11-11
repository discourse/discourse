# frozen_string_literal: true

module PageObjects
  module Pages
    class Poll < PageObjects::Pages::Base
      def initialize(topic_page: nil)
        @topic_page = topic_page || PageObjects::Pages::Topic.new
      end

      def has_poll_for_post?(post)
        @topic_page.post_by_number(post.post_number).has_css?(".poll")
      end

      def find_poll_for_post(post)
        @topic_page.post_by_number(post.post_number).find(".poll")
      end

      def has_option?(post, option)
        post_element = @topic_page.post_by_number(post.post_number)
        post_element.has_css?(".poll .option-text", text: option)
      end

      def has_no_option?(post, option)
        post_element = @topic_page.post_by_number(post.post_number)
        post_element.has_no_css?(".poll .option-text", text: option)
      end

      def vote_for_option(post, option)
        post_element = @topic_page.post_by_number(post.post_number)
        post_element.find("li[data-poll-option-id] button", text: option).click
      end

      def has_vote_count?(post, count)
        post_element = @topic_page.post_by_number(post.post_number)
        post_element.has_css?(".poll .info-number", text: count.to_s)
      end
    end
  end
end
