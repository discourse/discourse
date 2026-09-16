# frozen_string_literal: true

class MoveEditDraftsToEditPostKeys < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  BATCH_SIZE = 1000

  def up
    last_id = 0

    loop do
      rows = DB.query(<<~SQL, last_id:, batch_size: BATCH_SIZE)
        SELECT id, user_id, sequence, data
        FROM drafts
        WHERE id > :last_id
          AND draft_key LIKE 'topic\\_%'
          AND data LIKE '%"action":"edit%'
        ORDER BY id
        LIMIT :batch_size
      SQL

      break if rows.empty?
      last_id = rows.last.id

      rows.each do |row|
        post_id =
          begin
            JSON.parse(row.data)["postId"]
          rescue JSON::ParserError
            nil
          end

        next if !post_id.is_a?(Integer)

        move_draft(row, "edit_post_#{post_id}")
      end
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  def move_draft(row, new_key)
    # a draft already saved under the new key is newer than the legacy one
    if DB.query_single(<<~SQL, user_id: row.user_id, new_key:).first
         SELECT 1 FROM drafts WHERE user_id = :user_id AND draft_key = :new_key
       SQL
      DB.exec(<<~SQL, id: row.id)
        DELETE FROM upload_references WHERE target_type = 'Draft' AND target_id = :id;
        DELETE FROM drafts WHERE id = :id;
      SQL
      return
    end

    DB.exec(<<~SQL, id: row.id, user_id: row.user_id, sequence: row.sequence, new_key:)
      INSERT INTO draft_sequences (user_id, draft_key, sequence)
      VALUES (:user_id, :new_key, :sequence)
      ON CONFLICT (user_id, draft_key) DO NOTHING;

      UPDATE drafts
      SET draft_key = :new_key,
          sequence = (
            SELECT sequence FROM draft_sequences
            WHERE user_id = :user_id AND draft_key = :new_key
          )
      WHERE id = :id;
    SQL
  end
end
