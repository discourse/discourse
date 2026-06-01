# frozen_string_literal: true

module Jobs
  class CleanUpBrowserPageviewEvents < ::Jobs::Scheduled
    every 1.day

    RETENTION_PERIOD = 3.months

    def execute(args)
      return if !SiteSetting.clean_up_browser_pageview_events

      BrowserPageviewEvent
        .where("created_at < ?", RETENTION_PERIOD.ago.beginning_of_day)
        .in_batches(of: 10_000) do |browser_pageview_events|
          BrowserPageviewEventScore.where(event_id: browser_pageview_events.select(:id)).delete_all
          browser_pageview_events.delete_all
        end
    end
  end
end
