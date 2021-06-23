# frozen_string_literal: true

class AddPostEditsCountToUserStats < ActiveRecord::Migration[6.1]
  def change
    add_column :user_stats, :post_edits_count, :integer, default: 0, null: false

    execute <<~SQL
      UPDATE user_stats us
      SET post_edits_count = editor.edits_count
      FROM (
        SELECT COUNT(editor.id) AS edits_count, editor.id AS id
        FROM post_revisions pr JOIN users editor ON editor.id = pr.user_id
        GROUP BY editor.id
      ) editor
      WHERE editor.id = us.user_id;
    SQL
  end
end
