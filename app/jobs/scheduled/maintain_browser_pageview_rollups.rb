# frozen_string_literal: true

module Jobs
  class MaintainBrowserPageviewRollups < ::Jobs::Scheduled
    every 10.minutes

    cluster_concurrency 1

    def execute(_args)
      return if !SiteSetting.persist_browser_pageview_events

      aggregate_pageviews
      aggregate_engagement
      backfill_referrers
    end

    private

    def aggregate_pageviews
      start_date, end_date = pageview_aggregation_window
      return if start_date.nil?

      BrowserPageviewCountryDailyRollup.aggregate(start_date: start_date, end_date: end_date)
      BrowserPageviewReferrerDailyRollup.aggregate(start_date: start_date, end_date: end_date)
    end

    def aggregate_engagement
      start_date, end_date = engagement_aggregation_window
      return if start_date.nil?

      BrowserPageviewSessionEngagementDailyRollup.aggregate(
        start_date: start_date,
        end_date: end_date,
      )
    end

    def engagement_aggregation_window
      end_date = Time.zone.today
      start_date =
        BrowserPageviewSessionEngagementDailyRollup.where("date < ?", end_date).maximum(:date) ||
          BrowserPageviewSessionEngagement.minimum(:created_at)&.to_date
      return nil, nil if start_date.nil?

      [start_date, end_date]
    end

    def pageview_aggregation_window
      end_date = Time.zone.today

      if BrowserPageviewCountryDailyRollup.none? && BrowserPageviewReferrerDailyRollup.none?
        earliest_event_date =
          BrowserPageviewEvent
            .where(source: BrowserPageviewEvent.rollup_source)
            .minimum(:created_at)
            &.to_date
        [earliest_event_date, end_date]
      else
        [1.day.ago.to_date, end_date]
      end
    end

    def backfill_referrers
      rows = next_batch
      return if rows.empty?

      ids = rows.map(&:id)

      store_normalized_referrers(rows)
      BrowserPageviewReferrerDailyRollup.recompute(recomputable_dates(ids))
      stamp_version(ids)
    end

    def next_batch
      params = {
        source: BrowserPageviewEvent.rollup_source,
        version: BrowserPageviewReferrerInspector::VERSION,
        limit: batch_size,
      }

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
          AND source = :source
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

    def recomputable_dates(ids)
      params = {
        ids: ids,
        source: BrowserPageviewEvent.rollup_source,
        version: BrowserPageviewReferrerInspector::VERSION,
      }

      retention_clause = ""
      if SiteSetting.clean_up_browser_pageview_events
        retention_clause = "AND e.created_at >= :retention_cutoff"
        params[:retention_cutoff] = BrowserPageviewEvent.retention_cutoff + 1.day
      end

      DB.query_single(<<~SQL, params)
        WITH batch_ids AS (
          SELECT unnest(ARRAY[:ids]::bigint[]) AS id
        ),
        touched_dates AS (
          SELECT DISTINCT created_at::date AS date
          FROM browser_pageview_events
          WHERE id IN (:ids)
        )
        SELECT touched_dates.date
        FROM touched_dates
        WHERE NOT EXISTS (
          SELECT 1
          FROM browser_pageview_events e
          WHERE e.created_at >= touched_dates.date
            AND e.created_at < touched_dates.date + 1
            AND e.source = :source
            AND e.referrer IS NOT NULL
            AND NOT EXISTS (
              SELECT 1
              FROM batch_ids
              WHERE batch_ids.id = e.id
            )
            AND (
              e.normalized_referrer_version IS NULL
              OR e.normalized_referrer_version < :version
            )
            #{retention_clause}
        )
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
