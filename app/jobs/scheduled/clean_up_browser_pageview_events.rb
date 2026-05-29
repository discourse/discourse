# frozen_string_literal: true

module Jobs
  class CleanUpBrowserPageviewEvents < ::Jobs::Scheduled
    every 1.day

    RETENTION_PERIOD = 3.months

    def execute(args)
      return if !SiteSetting.clean_up_browser_pageview_events

      cutoff = RETENTION_PERIOD.ago.beginning_of_day

      # Prune whole days one at a time under the rollups lock so that
      # BrowserPageviewReferrerDailyRollup.recompute (which rebuilds a day from
      # its events) never observes a partially-deleted day.
      while (oldest = BrowserPageviewEvent.where("created_at < ?", cutoff).minimum(:created_at))
        day = oldest.beginning_of_day

        DistributedMutex.synchronize(
          Jobs::AggregateBrowserPageviewDailyRollups::LOCK_KEY,
          validity: 10.minutes,
        ) do
          BrowserPageviewEvent
            .where("created_at >= ? AND created_at < ?", day, day + 1.day)
            .in_batches(of: 10_000) do |browser_pageview_events|
              BrowserPageviewEventScore.where(
                event_id: browser_pageview_events.select(:id),
              ).delete_all
              browser_pageview_events.delete_all
            end
        end
      end
    end
  end
end
