# frozen_string_literal: true

class BackfillEmailLogTopicId < ActiveRecord::Migration[6.1]
  disable_ddl_transaction!
  BATCH_SIZE = 30_000

  def up
    loop do
      count = DB.exec(<<~SQL, batch_size: BATCH_SIZE)
          WITH cte AS (
            SELECT l1.id, p1.topic_id
            FROM email_logs l1
            INNER JOIN posts p1 ON p1.id = l1.post_id
            WHERE l1.topic_id IS NULL AND p1.topic_id IS NOT NULL
            LIMIT :batch_size
          )
          UPDATE email_logs
          SET topic_id = cte.topic_id
          FROM cte
          WHERE email_logs.id = cte.id
      SQL

      break if count == 0
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
