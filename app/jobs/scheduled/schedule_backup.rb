# frozen_string_literal: true

module Jobs
  class ScheduleBackup < ::Jobs::Scheduled
    daily at: 0.hours
    sidekiq_options retry: false

    def execute(args)
      delete_prior_to_n_days
      return if !SiteSetting.enable_backups?
      return if SiteSetting.backup_frequency.zero?

      store = BackupRestore::BackupStore.create
      if latest_backup = store.latest_file
        date = latest_backup.last_modified.to_date
        return if (date + SiteSetting.backup_frequency.days) > Time.now.utc.to_date
      end

      ::Jobs.cancel_scheduled_job(:create_backup)

      time_of_day = Time.parse(SiteSetting.backup_time_of_day)
      seconds = time_of_day.hour.hours + time_of_day.min.minutes + rand(10.minutes)

      ::Jobs.enqueue_in(seconds, :create_backup)
    rescue => e
      notify_user(e)
      raise
    end

    def delete_prior_to_n_days
      BackupRestore::Backuper.new(Discourse.system_user.id).delete_prior_to_n_days
    end

    def notify_user(ex)
      SystemMessage.create_from_system_user(
        Discourse.system_user,
        :backup_failed,
        target_group_names: Group[:admins].name,
        logs: "#{ex}\n" + ex.backtrace.join("\n"),
      )
    end
  end
end
