# frozen_string_literal: true

module Reports::StorageStats
  extend ActiveSupport::Concern

  class_methods do
    def report_storage_stats(report)
      backup_stats =
        begin
          BackupRestore::BackupStore.create.stats
        rescue BackupRestore::BackupStore::StorageError
          nil
        end

      report.data = {
        backups: backup_stats,
        uploads: {
          used_bytes: DiskSpace.uploads_used_bytes,
          free_bytes: DiskSpace.uploads_free_bytes,
        },
      }
    end
  end
end
