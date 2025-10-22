# frozen_string_literal: true

class RenameSequences < ActiveRecord::Migration[7.0]
  def up
    rename_sequence(
      "discourse_voting_topic_vote_count_id_seq",
      "topic_voting_topic_vote_count_id_seq",
    )
    rename_sequence("discourse_voting_votes_id_seq", "topic_voting_votes_id_seq")
    rename_sequence(
      "discourse_voting_category_settings_id_seq",
      "topic_voting_category_settings_id_seq",
    )
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  def rename_sequence(existing_sequence_name, new_name)
    execute <<~SQL
      ALTER SEQUENCE #{existing_sequence_name}
      RENAME TO #{new_name};
    SQL
  end
end
