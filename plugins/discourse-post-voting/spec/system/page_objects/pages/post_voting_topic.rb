# frozen_string_literal: true

module PageObjects
  module Pages
    class PostVotingTopic < PageObjects::Pages::Topic
      COMMENT_VOTE_BUTTON = ".post-voting-comment-actions-vote button"
      POST_VOTE_BUTTON = ".post-voting-post button"
      COMMENT_ACTIONS = ".post-voting-comment-actions"
    end
  end
end
