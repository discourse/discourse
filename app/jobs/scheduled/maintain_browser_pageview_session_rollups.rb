# frozen_string_literal: true

module Jobs
  # Separate from MaintainBrowserPageviewRollups so the most expensive
  # aggregate (window functions over a multi-day scan) never delays the
  # country/referrer rollups or the referrer backfill that share that job's
  # cluster-serialized slot.
  class MaintainBrowserPageviewSessionRollups < ::Jobs::Scheduled
    every 10.minutes

    cluster_concurrency 1

    # Exit pings only exist from the moment the engagements migration ran on
    # this site. Days before that cannot evaluate the bounce and duration
    # definitions, so aggregating them would permanently misclassify every
    # pre-instrumentation single-pageview visit as a zero-duration bounce.
    # Writing no row for those days is honest; writing an inflated one is not.
    ENGAGEMENTS_MIGRATION_VERSION = "20260610025606"
    private_constant :ENGAGEMENTS_MIGRATION_VERSION

    def execute(_args)
      return if !SiteSetting.persist_browser_pageview_events

      start_date, end_date = aggregation_window
      return if start_date.nil? || start_date > end_date

      BrowserPageviewSessionDailyRollup.aggregate(start_date: start_date, end_date: end_date)
    end

    private

    def aggregation_window
      cutoff = instrumented_on
      return nil, nil if cutoff.nil?

      end_date = Time.zone.today
      start_date = BrowserPageviewSessionDailyRollup.none? ? cutoff : 1.day.ago.to_date

      [[start_date, cutoff].max, end_date]
    end

    def instrumented_on
      DB
        .query_single(
          "SELECT created_at FROM schema_migration_details WHERE version = :version",
          version: ENGAGEMENTS_MIGRATION_VERSION,
        )
        .first
        &.to_date
    end
  end
end
