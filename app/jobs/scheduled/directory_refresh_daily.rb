module Jobs
  class DirectoryRefreshDaily < Jobs::Scheduled
    every 1.hour

    def execute(args)
      DirectoryItem.refresh_period!(:daily)
    end
  end
end
