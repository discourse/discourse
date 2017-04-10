module Jobs
  class RemoveOldAutoCloseJobs < Jobs::Onceoff
    def execute_onceoff(args)
      Jobs.cancel_scheduled_job(:close_topic)

      # No need to enqueue new jobs since we have a scheduled job that will
      # automatically enqueue the new jobs.
    end
  end
end
