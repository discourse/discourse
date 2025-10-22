# frozen_string_literal: true

Fabricator(:post_voting_vote, class_name: :post_voting_vote) do
  user
  votable(fabricator: :post)
  direction "up"
end
