module Jobs
  class DirectoryRefresh < Jobs::Scheduled
    every 1.hour

    def execute(args)
      DirectoryItem.refresh!
    end
  end
end
