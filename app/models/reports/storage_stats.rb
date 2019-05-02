# frozen_string_literal: true

Report.add_report("storage_stats") do |report|
  backup_stats = begin
    BackupRestore::BackupStore.create.stats
  rescue BackupRestore::BackupStore::StorageError
    nil
  end

  report.data = {
    backups: backup_stats,
    uploads: {
      used_bytes: DiskSpace.uploads_used_bytes,
      free_bytes: DiskSpace.uploads_free_bytes
    }
  }
end
