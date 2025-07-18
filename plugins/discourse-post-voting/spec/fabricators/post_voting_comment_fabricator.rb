# frozen_string_literal: true

Fabricator(:post_voting_comment) do
  user
  post
  raw "Hello world"
end

Fabricator(:reviewable_post_voting_comment, class_name: "ReviewablePostVotingComment") do
  reviewable_by_moderator true
  type "ReviewablePostVotingComment"
  created_by { Fabricate(:user) }
  target { Fabricate(:post_voting_comment) }
  reviewable_scores { |p| [Fabricate.build(:reviewable_score, reviewable_id: p[:id])] }
end
