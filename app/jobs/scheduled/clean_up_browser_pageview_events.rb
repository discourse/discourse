# frozen_string_literal: true

module Jobs
  class CleanUpBrowserPageviewEvents < ::Jobs::Scheduled
    every 1.day

    BATCH_SIZE = 10_000

    def execute(args)
      return if !SiteSetting.clean_up_browser_pageview_events

      cutoff = BrowserPageviewEvent.retention_cutoff

      BrowserPageviewEvent
        .where("created_at < ?", cutoff)
        .in_batches(of: BATCH_SIZE) do |browser_pageview_events|
          BrowserPageviewEventScore.where(event_id: browser_pageview_events.select(:id)).delete_all
          browser_pageview_events.delete_all
        end

      BrowserPageviewSessionEngagement
        .where("created_at < ?", cutoff)
        .in_batches(of: BATCH_SIZE) { |session_engagements| session_engagements.delete_all }
    end
  end
end
