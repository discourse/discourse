# frozen_string_literal: true

class TriggerPostRebakeCategoryStyleQuotes < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def up
    max_id = DB.query_single(<<~SQL).first.to_i
      SELECT MAX(id)
      FROM posts
    SQL

    chunk_size = 100_000
    while max_id > 0
      ids = DB.query_single(<<~SQL, from: max_id, to: max_id - chunk_size)
        SELECT id
        FROM posts
        WHERE cooked LIKE '%blockquote%'
        AND id < :from and id >= :to
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
