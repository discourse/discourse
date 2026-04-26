# frozen_string_literal: true

class DropOldDiscourseVotingTables < ActiveRecord::Migration[7.0]
  def up
    drop_table :discourse_voting_topic_vote_count, if_exists: true
    drop_table :discourse_voting_votes, if_exists: true
    drop_table :discourse_voting_category_settings, if_exists: true
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
