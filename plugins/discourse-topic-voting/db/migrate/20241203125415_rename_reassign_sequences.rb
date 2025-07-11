# frozen_string_literal: true

class RenameReassignSequences < ActiveRecord::Migration[7.0]
  def up
    reassign_sequence("discourse_voting_topic_vote_count_id_seq", "topic_voting_topic_vote_count")
    reassign_sequence("discourse_voting_votes_id_seq", "topic_voting_votes")
    reassign_sequence("discourse_voting_category_settings_id_seq", "topic_voting_category_settings")
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  def reassign_sequence(sequence_name, new_table_name)
    execute <<~SQL
      ALTER SEQUENCE #{sequence_name}
      OWNED BY #{new_table_name}.id;
    SQL
  end
end
