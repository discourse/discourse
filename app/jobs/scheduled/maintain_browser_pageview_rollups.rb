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
      entry_url_rollups_initialized = BrowserPageviewEntryUrlDailyRollup.exists?
      backfill_referrers(recompute_entry_urls: entry_url_rollups_initialized)
      backfill_urls(recompute_entry_urls: entry_url_rollups_initialized)
      aggregate_entry_urls if referrer_backfill_complete? && url_backfill_complete?
      backfill_browsers
      backfill_languages
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

    def aggregate_entry_urls
      start_date, end_date = entry_url_aggregation_window

      BrowserPageviewEntryUrlDailyRollup.aggregate(start_date:, end_date:) if start_date
    end

    def entry_url_aggregation_window
      end_date = Time.zone.today
      start_date =
        if BrowserPageviewEntryUrlDailyRollup.none?
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

    def backfill_referrers(recompute_entry_urls:)
      rows = next_batch
      return if rows.empty?

      ids = rows.map(&:id)

      store_normalized_referrers(rows)
      referrer_dates = recomputable_dates(ids)
      entry_url_dates = entry_url_recomputable_dates(ids, backfill: :referrer)
      BrowserPageviewReferrerDailyRollup.recompute(referrer_dates)
      BrowserPageviewEntryUrlDailyRollup.recompute(entry_url_dates) if recompute_entry_urls
      stamp_version(ids)
    end

    def next_batch(limit: batch_size)
      params = { version: BrowserPageviewEventUrlNormalizer::REFERRER_VERSION, limit: }

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

    def referrer_backfill_complete?
      next_batch(limit: 1).empty?
    end

    def backfill_urls(recompute_entry_urls:)
      rows = url_batch
      return if rows.empty?

      ids = rows.map(&:id)
      normalized = rows.map { |row| BrowserPageviewEventUrlNormalizer.normalize_site_path(row.url) }

      DB.exec(<<~SQL, ids: ids, normalized: normalized)
          UPDATE browser_pageview_events AS e
          SET normalized_url = data.normalized_url
          FROM unnest(
            ARRAY[:ids]::bigint[],
            ARRAY[:normalized]::text[]
          ) AS data(id, normalized_url)
          WHERE e.id = data.id
        SQL
      if recompute_entry_urls
        BrowserPageviewEntryUrlDailyRollup.recompute(
          entry_url_recomputable_dates(ids, backfill: :url),
        )
      end
      stamp_url_version(ids)
    end

    def url_backfill_complete?
      url_batch(limit: 1).empty?
    end

    def entry_url_recomputable_dates(ids, backfill:)
      url_batch_condition = backfill == :url ? "AND events.id NOT IN (:ids)" : ""
      referrer_batch_condition = backfill == :referrer ? "AND events.id NOT IN (:ids)" : ""

      DB.query_single(
        <<~SQL,
          WITH touched_dates AS (
            SELECT DISTINCT created_at::date AS date
            FROM browser_pageview_events
            WHERE id IN (:ids)
          )
          SELECT touched_dates.date
          FROM touched_dates
          WHERE NOT EXISTS (
            SELECT 1
            FROM browser_pageview_events events
            WHERE events.created_at >= touched_dates.date
              AND events.created_at < touched_dates.date + 1
              AND #{BrowserPageviewEvent.rollup_source_condition(table: "events")}
              AND (
                (
                  (
                    events.normalized_url_version IS NULL
                    OR events.normalized_url_version < :url_version
                  )
                  #{url_batch_condition}
                )
                OR (
                  events.referrer IS NOT NULL
                  AND (
                    events.normalized_referrer_version IS NULL
                    OR events.normalized_referrer_version < :referrer_version
                  )
                  #{referrer_batch_condition}
                )
              )
          )
        SQL
        ids:,
        url_version: BrowserPageviewEventUrlNormalizer::SITE_PATH_VERSION,
        referrer_version: BrowserPageviewEventUrlNormalizer::REFERRER_VERSION,
      )
    end

    def stamp_url_version(ids)
      DB.exec(<<~SQL, version: BrowserPageviewEventUrlNormalizer::SITE_PATH_VERSION, ids: ids)
        UPDATE browser_pageview_events
        SET normalized_url_version = :version
        WHERE id IN (:ids)
      SQL
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

    def backfill_languages
      rows = language_batch
      return if rows.empty?

      ids = rows.map(&:id)
      normalized_languages =
        rows.map { |row| BrowserPageviewEventLanguageNormalizer.normalize(row.language) }

      DB.exec(<<~SQL, ids: ids, normalized_languages: normalized_languages)
          UPDATE browser_pageview_events AS events
          SET normalized_language = data.normalized_language
          FROM unnest(
            ARRAY[:ids]::bigint[],
            ARRAY[:normalized_languages]::text[]
          ) AS data(id, normalized_language)
          WHERE events.id = data.id
        SQL
    end

    def language_batch
      DB.query(<<~SQL, retention_cutoff: BrowserPageviewEvent.retention_cutoff, limit: batch_size)
          SELECT id, language
          FROM browser_pageview_events
          WHERE created_at >= :retention_cutoff
            AND #{BrowserPageviewEvent.rollup_source_condition}
            AND language IS NOT NULL
            AND normalized_language IS NULL
          ORDER BY created_at DESC, id DESC
          LIMIT :limit
        SQL
    end

    def url_batch(limit: batch_size)
      DB.query(
        <<~SQL,
          SELECT id, url
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
