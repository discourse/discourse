# frozen_string_literal: true
class SyncTimerableIdTopicId < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    min, max = DB.query_single "SELECT MIN(id), MAX(id) FROM topic_timers"
    # scaling is needed to compensate for "holes" where records were deleted
    # and pathological cases where for some reason id 100_000_000 and 0 exist

    # avoid doing any work on empty dbs
    return if min.nil?

    bounds = DB.query_single <<~SQL
      SELECT t.id
      FROM (
        SELECT *, row_number() OVER(ORDER BY id ASC) AS row
        FROM topic_timers
      ) t
      WHERE t.row % 100000 = 0
    SQL

    # subtle but loop does < not <=
    # includes low, excludes high
    bounds << (max + 1)

    low_id = min
    bounds.each do |high_id|
      # using execute cause MiniSQL is not logging at the moment
      # to_i is not needed, but specified so it is explicit there is no SQL injection
      execute <<~SQL
        UPDATE topic_timers SET timerable_id = topic_id
         WHERE (id >= #{low_id.to_i} AND id < #{high_id.to_i})
      SQL

      low_id = high_id
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
