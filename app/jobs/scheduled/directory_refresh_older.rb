module Jobs
  class DirectoryRefreshOlder < Jobs::Scheduled
    every 1.day

    def execute(args)
      periods = DirectoryItem.period_types.keys - [:daily]
      periods.each { |p| DirectoryItem.refresh_period!(p) }
    end
  end
end
