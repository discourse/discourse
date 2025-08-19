# frozen_string_literal: true

class MakePostVotingCommentLastEditorIdsNotNull < ActiveRecord::Migration[7.0]
  def change
    DB.exec("UPDATE post_voting_comments SET last_editor_id = user_id")

    change_column_null :post_voting_comments, :last_editor_id, false
  end
end
