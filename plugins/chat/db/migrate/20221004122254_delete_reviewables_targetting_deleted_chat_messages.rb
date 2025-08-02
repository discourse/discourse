# frozen_string_literal: true

class DeleteReviewablesTargettingDeletedChatMessages < ActiveRecord::Migration[7.0]
  def down
    raise ActiveRecord::IrreversibleMigration
  end

  def up
    deleted_ids = DB.query_single <<~SQL
      DELETE FROM reviewables r
      WHERE r.type = 'ReviewableChatMessage'
      AND r.id IN (
        SELECT raux.id
        FROM reviewables raux
        LEFT OUTER JOIN chat_messages cm ON cm.id = raux.target_id
        WHERE raux.type = 'ReviewableChatMessage' AND cm.id IS NULL
      )
      RETURNING r.id
    SQL

    if deleted_ids
      DB.exec(<<~SQL, deleted_ids: deleted_ids)
        DELETE FROM reviewable_scores rs
        WHERE rs.reviewable_id IN (:deleted_ids)
      SQL

      DB.exec(<<~SQL, deleted_ids: deleted_ids)
        DELETE FROM reviewable_histories rh
        WHERE rh.reviewable_id IN (:deleted_ids)
      SQL
    end
  end
end
