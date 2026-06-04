# frozen_string_literal: true

module Jobs
  class MaintainBrowserPageviewRollups < ::Jobs::Scheduled
    every 10.minutes

    cluster_concurrency 1

    def execute(_args)
      return if !SiteSetting.persist_browser_pageview_events

      aggregate
      backfill
    end

    private

    def aggregate
      start_date, end_date = aggregation_window
      return if start_date.nil?

      BrowserPageviewCountryDailyRollup.aggregate(start_date: start_date, end_date: end_date)
      BrowserPageviewReferrerDailyRollup.aggregate(start_date: start_date, end_date: end_date)
    end

    def aggregation_window
      end_date = Time.zone.today

      if BrowserPageviewCountryDailyRollup.none? && BrowserPageviewReferrerDailyRollup.none?
        earliest_event_date = BrowserPageviewEvent.minimum(:created_at)&.to_date
        [earliest_event_date, end_date]
      else
        [1.day.ago.to_date, end_date]
      end
    end

    def backfill
      rows = next_batch
      return if rows.empty?

      ids = rows.map(&:id)

      store_normalized_referrers(rows)
      BrowserPageviewReferrerDailyRollup.recompute(touched_dates(ids))
      stamp_version(ids)
    end

    def next_batch
      params = { version: BrowserPageviewReferrerInspector::VERSION, limit: batch_size }

      retention_clause = ""
      if SiteSetting.clean_up_browser_pageview_events
        retention_clause = "AND created_at >= :retention_cutoff"
        # CleanUpBrowserPageviewEvents computes its own cutoff, so around
        # midnight the two cutoffs can differ by a day. The extra day ensures
        # the backfill never rebuilds a day that cleanup may be deleting.
        params[:retention_cutoff] = BrowserPageviewEvent.retention_cutoff + 1.day
      end

      DB.query(<<~SQL, params)
        SELECT id, referrer
        FROM browser_pageview_events
        WHERE referrer IS NOT NULL
          AND (
            normalized_referrer_version IS NULL
            OR normalized_referrer_version < :version
          )
          #{retention_clause}
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
