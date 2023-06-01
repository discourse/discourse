# frozen_string_literal: true

class RebakeQuotes < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def up
    # following c2332d7505379c30e11d295d90f5224385736993 we need to rebake all quotes
    # this corrects the issue where quotes had 20 width images instead of 24 per new
    # settings
    rows = 1
    while rows > 0
      # limit DB contention
      rows = DB.exec <<~SQL
        UPDATE posts
        SET baked_version = -1
        WHERE id IN (
          SELECT p2.id
          FROM posts p2
          WHERE baked_version <> -1
           AND raw LIKE '%[quote%'
          LIMIT 20000
        )
      SQL
    end
  end
  def down
    # nothing to do
  end
end
