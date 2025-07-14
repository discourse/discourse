# frozen_string_literal: true

class AddLastEditorToPostVotingMessages < ActiveRecord::Migration[7.0]
  def change
    add_column :post_voting_comments, :last_editor_id, :integer
    add_index :post_voting_comments, :last_editor_id
  end
end
