# frozen_string_literal: true

module Jobs
  class FlushBrowserPageviewEvents < ::Jobs::Scheduled
    every 5.minutes

    MAX_FLUSH_SECONDS = 50

    def execute(args)
      return if !SiteSetting.persist_browser_pageview_events
      return if Discourse.pg_readonly_mode?

      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + MAX_FLUSH_SECONDS

      loop do
        return if BrowserPageviewEvent.queued_count == 0

        processed = BrowserPageviewEvent.flush_queued!
        return if processed < BrowserPageviewEvent::REDIS_FLUSH_BATCH_SIZE
        return if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
      end
    end
  end
end
