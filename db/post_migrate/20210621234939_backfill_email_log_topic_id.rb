# frozen_string_literal: true

class BackfillEmailLogTopicId < ActiveRecord::Migration[6.1]
  disable_ddl_transaction!
  BATCH_SIZE = 30_000

  def up
    offset = 0
    email_log_count = DB.query_single("SELECT COUNT(*) FROM email_logs").first

    loop do
      DB.exec(<<~SQL, offset: offset, batch_size: BATCH_SIZE)
          WITH cte AS (
            SELECT post_id
            FROM email_logs
            ORDER BY id
            LIMIT :batch_size
            OFFSET :offset
          )
          UPDATE email_logs
          SET topic_id = posts.topic_id
          FROM cte
          INNER JOIN posts ON posts.id = cte.post_id
          WHERE email_logs.post_id = cte.post_id
      SQL

      offset += BATCH_SIZE
      break if offset > (email_log_count + BATCH_SIZE * 2)
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
