# frozen_string_literal: true

module Jobs
  class DropBackupSchema < ::Jobs::Scheduled
    every 1.day

    def execute(_)
      BackupRestore::DatabaseRestorer.drop_backup_schema
    end
  end
end
