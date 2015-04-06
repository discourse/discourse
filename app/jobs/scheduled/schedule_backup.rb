
module Jobs
  class ScheduleBackup < Jobs::Scheduled
    daily at: 3.hours
    sidekiq_options retry: false

    def execute(args)
      return unless SiteSetting.backup_daily?
      Jobs.enqueue_in(rand(10.minutes), :create_daily_backup)
    end
  end
end
