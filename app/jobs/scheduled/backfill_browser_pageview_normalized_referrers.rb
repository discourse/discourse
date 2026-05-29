# frozen_string_literal: true

module Jobs
  class BackfillBrowserPageviewNormalizedReferrers < ::Jobs::Scheduled
    every 10.minutes

    sidekiq_options queue: "low"

    cluster_concurrency 1

    def execute(_args)
      return if !SiteSetting.persist_browser_pageview_events

      rows = next_batch
      return if rows.empty?

      ids = rows.map(&:id)

      store_normalized_referrers(rows)
      repair_rollups(touched_dates(ids))
      stamp_version(ids)
    end

    private

    def next_batch
      DB.query(<<~SQL, version: BrowserPageviewReferrerInspector::VERSION, limit: batch_size)
        SELECT id, referrer
        FROM browser_pageview_events
        WHERE referrer IS NOT NULL
          AND (
            normalized_referrer_version IS NULL
            OR normalized_referrer_version < :version
          )
        LIMIT :limit
      SQL
    end

    def store_normalized_referrers(rows)
      ids = rows.map(&:id)
      normalized = rows.map { |row| BrowserPageviewReferrerInspector.normalize(row.referrer) }

      DB.exec(<<~SQL, ids: ids, normalized: normalized)
        UPDATE browser_pageview_events AS e
        SET normalized_referrer = data.normalized_referrer
        FROM (
          SELECT
            unnest(ARRAY[:ids]::bigint[]) AS id,
            unnest(ARRAY[:normalized]::text[]) AS normalized_referrer
        ) AS data
        WHERE e.id = data.id
      SQL
    end

    def touched_dates(ids)
      DB.query_single(<<~SQL, ids: ids)
        SELECT DISTINCT created_at::date
        FROM browser_pageview_events
        WHERE id IN (:ids)
      SQL
    end

    def repair_rollups(dates)
      return if dates.empty?

      DistributedMutex.synchronize(
        Jobs::AggregateBrowserPageviewDailyRollups::LOCK_KEY,
        validity: 10.minutes,
      ) { BrowserPageviewReferrerDailyRollup.recompute(dates) }
    end

    def stamp_version(ids)
      DB.exec(<<~SQL, version: BrowserPageviewReferrerInspector::VERSION, ids: ids)
        UPDATE browser_pageview_events
        SET normalized_referrer_version = :version
        WHERE id IN (:ids)
      SQL
    end

    def batch_size
      SiteSetting.browser_pageview_referrer_backfill_batch_size
    end
  end
end
