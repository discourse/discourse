require_dependency "backup_restore"

module Jobs
  class CreateBackup < Jobs::Scheduled
    every 1.day
    sidekiq_options retry: false

    def execute(args)
      return unless SiteSetting.backup_daily?
      BackupRestore.backup!(Discourse.system_user.id, false)
    end
  end
end

