
module Jobs
  class ScheduleBackup < Jobs::Scheduled
    daily at: 0.hours
    sidekiq_options retry: false

    def execute(args)
      return unless SiteSetting.automatic_backups_enabled?

      if latest_backup = Backup.all[0]
        date = File.ctime(latest_backup.path).getutc.to_date
        return if (date + SiteSetting.backup_frequency.days) > Time.now.utc.to_date
      end

      Jobs.cancel_scheduled_job(:create_backup)

      time_of_day = Time.parse(SiteSetting.backup_time_of_day)
      seconds = time_of_day.hour.hours + time_of_day.min.minutes + rand(10.minutes)

      Jobs.enqueue_in(seconds, :create_backup)
    end
  end
end
