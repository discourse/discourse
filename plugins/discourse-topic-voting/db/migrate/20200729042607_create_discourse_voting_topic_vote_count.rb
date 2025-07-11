# frozen_string_literal: true

class CreateDiscourseVotingTopicVoteCount < ActiveRecord::Migration[6.0]
  def up
    create_table :discourse_voting_topic_vote_count do |t|
      t.integer :topic_id
      t.integer :votes_count
      t.timestamps
    end
    add_index :discourse_voting_topic_vote_count, :topic_id, unique: true

    DB.exec <<~SQL
      INSERT INTO discourse_voting_topic_vote_count(topic_id, votes_count, created_at, updated_at)
      SELECT topic_id::integer, value::integer, created_at, updated_at
      FROM topic_custom_fields
      WHERE name = 'vote_count'
      AND value <> ''
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
