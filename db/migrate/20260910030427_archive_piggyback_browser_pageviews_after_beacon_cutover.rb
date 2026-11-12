# frozen_string_literal: true

class ArchivePiggybackBrowserPageviewsAfterBeaconCutover < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  BATCH_SIZE = 10_000

  def up
    # Match ApplicationRequest's daily source selection without loading application code.
    cutover_date = DB.query_single(<<~SQL).first
      WITH first_beacon AS (
        SELECT MIN(date) AS date
        FROM application_requests
        WHERE req_type IN (17, 19) AND count > 0
      )
      SELECT CASE WHEN EXISTS (
        SELECT 1 FROM application_requests legacy
        WHERE legacy.date = first_beacon.date
          AND legacy.req_type IN (13, 15) AND legacy.count > 0
      ) THEN first_beacon.date + 1 ELSE first_beacon.date END
      FROM first_beacon
    SQL
    puts(
      if cutover_date.nil?
        "No cutover date found, skipping migration"
      else
        "Cutover date: #{cutover_date}"
      end,
    )
    return if cutover_date.nil?

    last_legacy_id = 0

    loop do
      last_processed_id =
        DB.query_single(<<~SQL, batch_size: BATCH_SIZE, last_legacy_id:, cutover_date:).first
          WITH legacy_events_batch AS MATERIALIZED (
            SELECT id
            FROM browser_pageview_events
            WHERE source = 1
              AND created_at >= :cutover_date
              AND id > :last_legacy_id
            ORDER BY id
            LIMIT :batch_size
          ),
          deleted_scores AS (
            DELETE FROM browser_pageview_event_scores scores
            USING legacy_events_batch
            WHERE scores.event_id = legacy_events_batch.id
            RETURNING scores.*
          ),
          archived_scores AS (
            INSERT INTO browser_pageview_event_scores_backup
            SELECT * FROM deleted_scores
          ),
          deleted_events AS (
            DELETE FROM browser_pageview_events events
            USING legacy_events_batch
            WHERE events.id = legacy_events_batch.id
            RETURNING events.*
          ),
          archived_events AS (
            INSERT INTO browser_pageview_events_backup
            SELECT * FROM deleted_events
          )
          SELECT MAX(id)
          FROM legacy_events_batch
        SQL

      break if last_processed_id.nil?
      last_legacy_id = last_processed_id
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
