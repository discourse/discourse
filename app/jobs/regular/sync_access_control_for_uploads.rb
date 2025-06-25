# frozen_string_literal: true

module Jobs
  # Sometimes we need to update the access control metadata for a _lot_ of objects on S3 (such as when secure uploads
  # is enabled), this is best spread out over many jobs instead of having to do the whole thing serially.
  class SyncAccessControlForUploads < ::Jobs::Base
    sidekiq_options queue: "low"

    def execute(args)
      return if !Discourse.store.external?
      return if !args.key?(:upload_ids)

      Upload
        .includes(:optimized_images)
        .where(id: args[:upload_ids])
        .find_in_batches do |uploads|
          uploads.each do |upload|
            begin
              Discourse.store.update_upload_access_control(upload, remove_existing_acl: true)
            rescue => err
              Discourse.warn_exception(
                err,
                message: "Failed to update upload access control",
                env: {
                  upload_id: upload.id,
                  filename: upload.original_filename,
                },
              )
            end
          end
        end
    end
  end
end
