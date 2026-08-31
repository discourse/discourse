# frozen_string_literal: true

class RemoveDuplicatedLegacyBrowserPageviewEvents < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  BATCH_SIZE = 10_000

  def up
    last_legacy_id = 0

    loop do
      last_processed_id = DB.query_single(<<~SQL, batch_size: BATCH_SIZE, last_legacy_id:).first
        WITH legacy_events_batch AS MATERIALIZED (
          SELECT id, session_id
          FROM browser_pageview_events
          WHERE source = 1
            AND id > :last_legacy_id
          ORDER BY id
          LIMIT :batch_size
        ),
        duplicated_legacy_events AS MATERIALIZED (
          SELECT legacy.id
          FROM legacy_events_batch legacy
          WHERE EXISTS (
              SELECT 1
              FROM browser_pageview_events beacon
              WHERE beacon.source = 2
                AND beacon.session_id = legacy.session_id
            )
          LIMIT :batch_size
        ),
        deleted_scores AS (
          DELETE FROM browser_pageview_event_scores scores
          USING duplicated_legacy_events
          WHERE scores.event_id = duplicated_legacy_events.id
        ),
        deleted_events AS (
          DELETE FROM browser_pageview_events events
          USING duplicated_legacy_events
          WHERE events.id = duplicated_legacy_events.id
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
