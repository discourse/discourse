require 'disk_space'

module Jobs
  class UpdateDiskSpace < Jobs::Base
    sidekiq_options retry: false

    def execute(args)
      $redis.set(DiskSpace::DISK_SPACE_STATS_CACHE_KEY, DiskSpace.stats.to_json)
      $redis.set(DiskSpace::DISK_SPACE_STATS_UPDATED_CACHE_KEY, Time.now.to_i)
    end
  end
end
