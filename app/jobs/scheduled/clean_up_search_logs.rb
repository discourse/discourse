module Jobs
  class CleanUpSearchLogs < Jobs::Scheduled
    every 1.week

    def execute(args)
      SearchLog.clean_up
    end
  end
end
