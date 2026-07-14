# frozen_string_literal: true

class AddTopicIdCreatedAtIndexToTopicVotingVotes < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def up
    remove_index :topic_voting_votes, %i[topic_id created_at], if_exists: true
    add_index :topic_voting_votes, %i[topic_id created_at], algorithm: :concurrently
  end

  def down
    remove_index :topic_voting_votes, %i[topic_id created_at], if_exists: true
  end
end
