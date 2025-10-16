# frozen_string_literal: true

module DiscourseDev
  class ReviewablePostVotingComment < Reviewable
    def populate!
      topic = Topic.new().create!
      topic.update_column(:subtype, ::Topic::POST_VOTING_SUBTYPE)
      post = topic.posts.first
      comment =
        PostVotingComment.create!(
          user: @users.sample,
          post: post,
          raw: "This is a comment for post #{post.id}",
        )
      user = @users.sample
      reviewable =
        ::ReviewablePostVotingComment.needs_review!(
          created_by: user,
          target: comment,
          reviewable_by_moderator: true,
          topic: topic,
          target_created_by: comment.user,
          payload: {
            comment_cooked: comment.cooked,
          },
        )
      reviewable.add_score(user, ReviewableScore.types[:inappropriate], force_review: true)
    end
  end
end
