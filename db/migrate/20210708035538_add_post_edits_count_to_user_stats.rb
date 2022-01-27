# frozen_string_literal: true

class AddPostEditsCountToUserStats < ActiveRecord::Migration[6.1]
  disable_ddl_transaction!
  BATCH_SIZE = 30_000

  def up
    add_column :user_stats, :post_edits_count, :integer

    loop do
      count = DB.exec(<<~SQL, batch_size: BATCH_SIZE)
        UPDATE user_stats us
        SET post_edits_count = editor.edits_count
        FROM (
          SELECT COUNT(editor.id) AS edits_count, editor.id AS id
          FROM post_revisions pr JOIN users editor ON editor.id = pr.user_id
          JOIN user_stats us ON us.user_id = editor.id
          WHERE us.post_edits_count IS NULL AND pr.user_id IS NOT NULL
          GROUP BY editor.id
          LIMIT :batch_size
        ) editor
        WHERE editor.id = us.user_id;
      SQL
      break if count == 0
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
