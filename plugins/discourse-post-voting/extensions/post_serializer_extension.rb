# frozen_string_literal: true

module PostVoting
  module PostSerializerExtension
    def self.included(base)
      base.attributes(
        :post_voting_vote_count,
        :post_voting_user_voted_direction,
        :post_voting_has_votes,
        :comments,
        :comments_count,
      )
    end

    def post_voting_vote_count
      object.qa_vote_count
    end

    def include_post_voting_vote_count?
      object.is_post_voting_topic?
    end

    def comments
      return [] if !@topic_view

      (@topic_view.comments[object.id] || []).map do |comment|
        serializer = PostVotingCommentSerializer.new(comment, scope: scope, root: false)
        serializer.comments_user_voted = @topic_view.comments_user_voted
        serializer.as_json
      end
    end

    def include_comments?
      object.is_post_voting_topic?
    end

    def comments_count
      @topic_view&.comments_counts&.dig(object.id) || 0
    end

    def include_comments_count?
      object.is_post_voting_topic?
    end

    def post_voting_user_voted_direction
      @topic_view.posts_user_voted[object.id]
    end

    def include_post_voting_user_voted_direction?
      @topic_view && object.is_post_voting_topic? && @topic_view.posts_user_voted.present?
    end

    def post_voting_has_votes
      !!@topic_view&.posts_voted_on&.include?(object.id)
    end

    def include_post_voting_has_votes?
      object.is_post_voting_topic?
    end

    private

    def topic
      @topic_view ? @topic_view.topic : object.topic
    end
  end
end
