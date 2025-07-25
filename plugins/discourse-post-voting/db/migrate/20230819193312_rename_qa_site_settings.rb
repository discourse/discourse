# frozen_string_literal: true

class RenameQaSiteSettings < ActiveRecord::Migration[7.0]
  def up
    [
      %w[qa_enabled post_voting_enabled],
      %w[qa_undo_vote_action_window post_voting_undo_vote_action_window],
      %w[qa_comment_limit_per_post post_voting_comment_limit_per_post],
      %w[qa_comment_max_raw_length post_voting_comment_max_raw_length],
      %w[qa_enable_likes_on_answers post_voting_enable_likes_on_answers],
    ].each { |old_name, new_name| execute <<~SQL }
      UPDATE site_settings
      SET name = '#{new_name}'
      WHERE name = '#{old_name}'
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
