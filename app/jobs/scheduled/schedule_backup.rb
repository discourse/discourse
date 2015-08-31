
module Jobs
  class ScheduleBackup < Jobs::Scheduled
    daily at: 3.hours
    sidekiq_options retry: false

    def execute(args)
      return unless SiteSetting.automatic_backups_enabled?

      if latest_backup = Backup.all[0]
        date = File.ctime(latest_backup.path).to_date
        return if (date + SiteSetting.backup_frequency.days) > Time.now.to_date
      end

      Jobs.enqueue_in(rand(10.minutes), :create_backup)
    end
  end
end
