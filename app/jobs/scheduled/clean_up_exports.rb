module Jobs
  class CleanUpExports < Jobs::Scheduled
    every 1.day

    def execute(args)
      UserExport.remove_old_exports
    end
  end
end
