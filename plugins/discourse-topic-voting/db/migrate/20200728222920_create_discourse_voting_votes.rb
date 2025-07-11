# frozen_string_literal: true

class CreateDiscourseVotingVotes < ActiveRecord::Migration[6.0]
  def up
    create_table :discourse_voting_votes do |t|
      t.integer :topic_id
      t.integer :user_id
      t.boolean :archive, default: false
      t.timestamps
    end
    add_index :discourse_voting_votes, %i[user_id topic_id], unique: true

    DB.exec <<~SQL
      INSERT INTO discourse_voting_votes(topic_id, user_id, archive, created_at, updated_at)
      SELECT value::integer, user_id, 'false', created_at, updated_at
      FROM user_custom_fields
      WHERE name = 'votes'
      AND value <> ''
      ON CONFLICT(user_id, topic_id) DO NOTHING
    SQL

    DB.exec <<~SQL
      INSERT INTO discourse_voting_votes(topic_id, user_id, archive, created_at, updated_at)
      SELECT value::integer, user_id, 'true', created_at, updated_at
      FROM user_custom_fields
      WHERE name = 'votes_archive'
      AND value <> ''
      ON CONFLICT(user_id, topic_id) DO NOTHING
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
