# frozen_string_literal: true

module PageObjects
  module Pages
    class PostVotingTopic < PageObjects::Pages::Topic
      COMMENT_VOTE_BUTTON = ".post-voting-comments__vote button"
      POST_VOTE_BUTTON = ".post-voting-post button"
      COMMENT_ACTIONS = ".post-voting-comments__comment-actions"

      def has_no_comment_menu?
        has_no_css?(".post-voting-comments__menu")
      end

      def click_vote_count(post)
        find("#post_#{post.post_number} .post-voting-post__toggle-voters").click
        self
      end

      def has_no_remaining_voters_label?
        has_no_text?("more user")
      end
    end
  end
end
