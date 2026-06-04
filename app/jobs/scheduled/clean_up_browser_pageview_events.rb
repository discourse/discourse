# frozen_string_literal: true

module Jobs
  class CleanUpBrowserPageviewEvents < ::Jobs::Scheduled
    every 1.day

    def execute(args)
      return if !SiteSetting.clean_up_browser_pageview_events

      BrowserPageviewEvent
        .where("created_at < ?", BrowserPageviewEvent.retention_cutoff)
        .in_batches(of: 10_000) do |browser_pageview_events|
          BrowserPageviewEventScore.where(event_id: browser_pageview_events.select(:id)).delete_all
          browser_pageview_events.delete_all
        end
    end
  end
end
