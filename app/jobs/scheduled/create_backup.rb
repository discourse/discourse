require "backup_restore/backup_restore"

module Jobs
  class CreateBackup < Jobs::Scheduled
    daily at: 3.hours
    sidekiq_options retry: false

    def execute(args)
      return unless SiteSetting.backup_daily?
      BackupRestore.backup!(Discourse.system_user.id, publish_to_message_bus: false)
    end
  end
end

