# frozen_string_literal: true

class TriggerAutoLinkingForVideosSincePlaceholder < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def up
    # Rebake any existing video placeholder posts to ensure they are auto-linked
    # to post uploads
    max_id = DB.query_single(<<~SQL).first.to_i
      SELECT MAX(id)
      FROM posts
    SQL

    chunk_size = 100_000
    while max_id > 0
      ids = DB.query_single(<<~SQL, start: max_id - chunk_size, finish: max_id)
        SELECT id
        FROM posts
        WHERE cooked LIKE '%video-placeholder-container%'
        AND id > :start AND id <= :finish
      SQL

      DB.exec(<<~SQL, ids: ids) if ids && ids.length > 0
          UPDATE posts
          SET baked_version = NULL
          WHERE id IN (:ids)
        SQL

      max_id -= chunk_size
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
