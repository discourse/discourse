# frozen_string_literal: true

class UpdateThreadReplyCounts < ActiveRecord::Migration[7.0]
  def up
    DB.exec <<~SQL
      UPDATE chat_threads threads
      SET replies_count = subquery.replies_count
      FROM (
        SELECT COUNT(*) - 1 AS replies_count, thread_id
        FROM chat_messages
        WHERE chat_messages.deleted_at IS NULL AND thread_id IS NOT NULL
        GROUP BY thread_id
      ) subquery
      WHERE threads.id = subquery.thread_id
      AND subquery.replies_count != threads.replies_count
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
