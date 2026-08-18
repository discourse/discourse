# frozen_string_literal: true

module Jobs
  class MaintainBrowserPageviewRollups < ::Jobs::Scheduled
    every 10.minutes

    cluster_concurrency 1

    def execute(_args)
      return if !SiteSetting.persist_browser_pageview_events

      aggregate_pageviews
      aggregate_engagement
      aggregate_crawlers
      backfill_referrers
      backfilled_url_dates = backfill_urls
      dirty_entry_url_dates = BrowserPageviewEntryUrlDirtyDate.snapshot
      url_backfill_complete = url_backfill_complete?
      BrowserPageviewEntryUrlDailyRollupDate.delete_all if !url_backfill_complete
      aggregate_entry_urls(
        backfilled_url_dates | dirty_entry_url_dates.map(&:first).uniq,
        url_backfill_complete:,
      )
      BrowserPageviewEntryUrlDirtyDate.clear!(dirty_entry_url_dates)
      backfill_browsers
    end

    private

    def aggregate_crawlers
      return if !CrawlerScorer.enabled?

      start_date, end_date = crawler_aggregation_window
      return if start_date.nil?

      BrowserPageviewCrawlerDailyRollup.aggregate(start_date: start_date, end_date: end_date)
    end

    def crawler_aggregation_window
      end_date = Time.zone.today

      if BrowserPageviewCrawlerDailyRollup.none?
        [earliest_event_date, end_date]
      else
        [1.day.ago.to_date, end_date]
      end
    end

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

    def aggregate_entry_urls(affected_dates, url_backfill_complete:)
      if !url_backfill_complete
        affected_dates.each do |date|
          BrowserPageviewEntryUrlDailyRollup.aggregate(
            start_date: date,
            end_date: date,
            record_coverage: false,
          )
        end
        return
      end

      start_date, end_date = entry_url_aggregation_window
      return if start_date.nil?

      BrowserPageviewEntryUrlDailyRollup.aggregate(start_date:, end_date:)
      affected_dates.each do |date|
        next if date >= start_date && date <= end_date

        BrowserPageviewEntryUrlDailyRollup.aggregate(
          start_date: date,
          end_date: date,
          record_coverage: false,
        )
      end
    end

    def entry_url_aggregation_window
      end_date = Time.zone.today
      start_date =
        if BrowserPageviewEntryUrlDailyRollupDate.none?
          earliest_event_date
        else
          1.day.ago.to_date
        end

      [start_date, end_date]
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
        [earliest_event_date, end_date]
      else
        [1.day.ago.to_date, end_date]
      end
    end

    def earliest_event_date
      BrowserPageviewEvent
        .where(BrowserPageviewEvent.rollup_source_condition)
        .minimum(:created_at)
        &.to_date
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
      params = { version: BrowserPageviewEventUrlNormalizer::REFERRER_VERSION, limit: batch_size }

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
          AND #{BrowserPageviewEvent.rollup_source_condition}
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
      normalized =
        rows.map { |row| BrowserPageviewEventUrlNormalizer.normalize_referrer(row.referrer) }

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
      params = { ids: ids, version: BrowserPageviewEventUrlNormalizer::REFERRER_VERSION }

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
            AND #{BrowserPageviewEvent.rollup_source_condition(table: "e")}
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
      DB.exec(<<~SQL, version: BrowserPageviewEventUrlNormalizer::REFERRER_VERSION, ids: ids)
        UPDATE browser_pageview_events
        SET normalized_referrer_version = :version
        WHERE id IN (:ids)
      SQL
    end

    def backfill_urls
      rows = url_batch
      return [] if rows.empty?

      ids = rows.map(&:id)
      normalized = rows.map { |row| BrowserPageviewEventUrlNormalizer.normalize_site_path(row.url) }
      dirty_events = rows.map { |row| [row.created_at, row.session_id] }

      BrowserPageviewEvent.transaction do
        DB.exec(
          <<~SQL,
            UPDATE browser_pageview_events AS e
            SET
              normalized_url = data.normalized_url,
              normalized_url_version = :version
            FROM unnest(
              ARRAY[:ids]::bigint[],
              ARRAY[:normalized]::text[]
            ) AS data(id, normalized_url)
            WHERE e.id = data.id
          SQL
          ids: ids,
          normalized: normalized,
          version: BrowserPageviewEventUrlNormalizer::SITE_PATH_VERSION,
        )
        BrowserPageviewEntryUrlDirtyDate.mark!(dirty_events)
      end

      dirty_events.map { |created_at, _session_id| created_at.to_date }.uniq
    end

    def url_backfill_complete?
      url_batch(limit: 1).empty?
    end

    def backfill_browsers
      rows = browser_batch
      return if rows.empty?

      ids = rows.map(&:id)
      browsers =
        rows.map do |row|
          BrowserPageviewEvent.browsers.fetch(
            BrowserDetection.browser(row.user_agent).to_s,
            BrowserPageviewEvent::BROWSER_UNKNOWN,
          )
        end

      DB.exec(<<~SQL, ids: ids, browsers: browsers)
          UPDATE browser_pageview_events AS e
          SET browser = data.browser
          FROM unnest(
            ARRAY[:ids]::bigint[],
            ARRAY[:browsers]::smallint[]
          ) AS data(id, browser)
          WHERE e.id = data.id
        SQL
    end

    def browser_batch
      DB.query(<<~SQL, retention_cutoff: BrowserPageviewEvent.retention_cutoff, limit: batch_size)
          SELECT id, user_agent
          FROM browser_pageview_events
          WHERE created_at >= :retention_cutoff
            AND #{BrowserPageviewEvent.rollup_source_condition}
            AND browser IS NULL
          ORDER BY created_at DESC, id DESC
          LIMIT :limit
        SQL
    end

    def url_batch(limit: batch_size)
      DB.query(
        <<~SQL,
          SELECT id, url, created_at, session_id
          FROM browser_pageview_events
          WHERE created_at >= :retention_cutoff
            AND #{BrowserPageviewEvent.rollup_source_condition}
            AND (
              normalized_url_version IS NULL
              OR normalized_url_version < :version
            )
          ORDER BY id
          LIMIT :limit
        SQL
        retention_cutoff: BrowserPageviewEvent.retention_cutoff,
        version: BrowserPageviewEventUrlNormalizer::SITE_PATH_VERSION,
        limit:,
      )
    end

    def batch_size
      SiteSetting.browser_pageview_referrer_backfill_batch_size
    end
  end
end
