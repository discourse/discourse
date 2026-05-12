# frozen_string_literal: true

module Jobs
  class DirectoryRefresh < ::Jobs::Scheduled
    every 1.hour

    OLDER_PERIODS_REFRESH_KEY = "directory_older_periods_last_refresh"

    def execute(args)
      DirectoryItem.refresh_period!(:daily)

      older_periods = DirectoryItem.period_types.keys - [:daily]

      # on smaller site, update hourly, otherwise update daily
      if small_site? || older_periods_due?
        older_periods.each { |p| DirectoryItem.refresh_period!(p) }
        Discourse.redis.set(OLDER_PERIODS_REFRESH_KEY, Time.zone.now.to_i)
      end
    end

    private

    def small_site?
      limit = SiteSetting.directory_hourly_refresh_max_users
      limit > 0 && User.human_users.count <= limit
    end

    def older_periods_due?
      last = Discourse.redis.get(OLDER_PERIODS_REFRESH_KEY)
      last.nil? || Time.zone.at(last.to_i) < 23.hours.ago
    end
  end
end
