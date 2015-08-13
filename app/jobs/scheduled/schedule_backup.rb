
module Jobs
  class ScheduleBackup < Jobs::Scheduled
    daily at: 3.hours
    sidekiq_options retry: false

    def execute(args)
      return unless SiteSetting.backups_enabled?

      if latest_backup = Backup.all[0]
        date = Date.parse(latest_backup.filename[/\d{4}-\d{2}-\d{2}/])
        return if date + SiteSetting.backup_frequency.days > Time.now
      end

      Jobs.enqueue_in(rand(10.minutes), :create_backup)
    end
  end
end
