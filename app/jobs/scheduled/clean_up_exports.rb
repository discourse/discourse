module Jobs
  class CleanUpExports < Jobs::Scheduled
    every 2.day

    def execute(args)
      UserExport.remove_old_exports # delete exported CSV files older than 2 days
    end
  end
end
