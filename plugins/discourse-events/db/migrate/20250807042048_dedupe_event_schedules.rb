# frozen_string_literal: true

class DedupeEventSchedules < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def up
    execute <<~SQL
      CREATE INDEX IF NOT EXISTS
      idx_discourse_calendar_post_event_dates_event_id_starts_at_temp
      ON discourse_calendar_post_event_dates (event_id, starts_at)
    SQL

    max_id = nil
    ActiveRecord::Base.transaction do
      execute "LOCK TABLE discourse_calendar_post_event_dates IN SHARE MODE"
      result = DB.query_single("SELECT MAX(id) as max_id FROM discourse_calendar_post_event_dates")
      max_id = result.first || 0

      execute <<~SQL
        CREATE UNIQUE INDEX IF NOT EXISTS
        idx_discourse_calendar_post_event_dates_event_id_starts_at_new
        ON discourse_calendar_post_event_dates (event_id, starts_at)
        WHERE id > #{max_id}
      SQL
    end

    loop do
      result = execute(<<~SQL)
          DELETE FROM discourse_calendar_post_event_dates
          WHERE id IN (
            SELECT id FROM (
              SELECT id,
                     ROW_NUMBER() OVER (
                       PARTITION BY event_id, starts_at
                       ORDER BY id ASC
                     ) as rn
              FROM discourse_calendar_post_event_dates
              WHERE (event_id, starts_at) IN (
                SELECT event_id, starts_at
                FROM discourse_calendar_post_event_dates
                GROUP BY event_id, starts_at
                HAVING COUNT(*) > 1
              )
            ) duplicates
            WHERE rn > 1
            LIMIT 100000
          )
        SQL

      deleted_count = result.cmd_tuples || 0
      break if deleted_count == 0
      puts "Deleted #{deleted_count} duplicate records"
    end

    ActiveRecord::Base.transaction do
      execute <<~SQL
        DROP INDEX IF EXISTS
        idx_discourse_calendar_post_event_dates_event_id_starts_at_new
      SQL

      execute <<~SQL
        CREATE UNIQUE INDEX
        idx_discourse_calendar_post_event_dates_event_id_starts_at_unique
        ON discourse_calendar_post_event_dates (event_id, starts_at)
      SQL
    end

    execute <<~SQL
      DROP INDEX IF EXISTS
      idx_discourse_calendar_post_event_dates_event_id_starts_at_temp
    SQL
  end

  def down
    execute <<~SQL
      DROP INDEX IF EXISTS
      idx_discourse_calendar_post_event_dates_event_id_starts_at_unique
    SQL
  end
end
