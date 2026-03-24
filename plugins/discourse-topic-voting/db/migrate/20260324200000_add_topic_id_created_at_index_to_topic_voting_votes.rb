# frozen_string_literal: true

class AddTopicIdCreatedAtIndexToTopicVotingVotes < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_index :topic_voting_votes,
              %i[topic_id created_at],
              algorithm: :concurrently,
              if_not_exists: true
  end
end
