# frozen_string_literal: true

module Jobs
  class ScheduleBackup < ::Jobs::Scheduled
    daily at: 0.hours
    sidekiq_options retry: false

    def execute(args)
      return unless SiteSetting.enable_backups? && SiteSetting.automatic_backups_enabled?

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

    def notify_user(ex)
      post = SystemMessage.create_from_system_user(
        Discourse.system_user,
        :backup_failed,
        logs: "#{ex}\n" + ex.backtrace.join("\n")
      )
      post.topic.invite_group(Discourse.system_user, Group[:admins])
    end
  end
end
