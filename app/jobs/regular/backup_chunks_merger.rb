# frozen_string_literal: true

module Jobs

  class BackupChunksMerger < ::Jobs::Base
    sidekiq_options queue: 'critical', retry: false

    def execute(args)
      filename   = args[:filename]
      identifier = args[:identifier]
      chunks     = args[:chunks].to_i

      raise Discourse::InvalidParameters.new(:filename)   if filename.blank?
      raise Discourse::InvalidParameters.new(:identifier) if identifier.blank?
      raise Discourse::InvalidParameters.new(:chunks)     if chunks <= 0

      backup_path = "#{BackupRestore::LocalBackupStore.base_directory}/#{filename}"
      tmp_backup_path = "#{backup_path}.tmp"
      # path to tmp directory
      tmp_directory = File.dirname(BackupRestore::LocalBackupStore.chunk_path(identifier, filename, 0))

      # merge all chunks
      HandleChunkUpload.merge_chunks(
        chunks,
        upload_path: backup_path,
        tmp_upload_path: tmp_backup_path,
        identifier: identifier,
        filename: filename,
        tmp_directory: tmp_directory
      )

      # push an updated list to the clients
      store = BackupRestore::BackupStore.create
      data = ActiveModel::ArraySerializer.new(store.files, each_serializer: BackupFileSerializer).as_json
      MessageBus.publish("/admin/backups", data, user_ids: User.staff.pluck(:id))
    end

  end

end
