# frozen_string_literal: true

module Jobs
  class RemoveOldAutoCloseJobs < OnceoffBase
    def execute_onceoff(args)
      Jobs.cancel_scheduled_job(:close_topic)

      # No need to enqueue new jobs since we have a scheduled job that will
      # automatically enqueue the new jobs.
    end
  end
end
