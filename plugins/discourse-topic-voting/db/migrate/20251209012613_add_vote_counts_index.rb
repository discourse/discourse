# frozen_string_literal: true
class AddVoteCountsIndex < ActiveRecord::Migration[8.0]
  def change
    add_index :topic_voting_topic_vote_count,
              :votes_count,
              name: "index_topic_voting_topic_vote_count_on_votes_count"
  end
end
