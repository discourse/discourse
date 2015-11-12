require "backup_restore/backup_restore"

module Jobs
  class CreateBackup < Jobs::Base
    sidekiq_options retry: false

    def execute(args)
      BackupRestore.backup!(Discourse.system_user.id, publish_to_message_bus: false, with_uploads: SiteSetting.backup_with_uploads)
    end
  end
end
