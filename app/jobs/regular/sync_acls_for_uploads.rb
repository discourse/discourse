# frozen_string_literal: true

module Jobs
  # Sometimes we need to update a _lot_ of ACLs on S3 (such as when secure uploads
  # is enabled), and since it takes ~1s per upload to update the ACL, this is
  # best spread out over many jobs instead of having to do the whole thing serially.
  class SyncAclsForUploads < ::Jobs::Base
    sidekiq_options queue: "low"

    def execute(args)
      return if !Discourse.store.external?
      return if !args.key?(:upload_ids)

      # NOTE: These log messages are set to warn to ensure this is working
      # as intended in initial production trials, this will need to be set to debug
      # after an acl_stale column is added to uploads.
      time =
        Benchmark.measure do
          Rails.logger.warn("Syncing ACL for upload ids: #{args[:upload_ids].join(", ")}")
          Upload
            .includes(:optimized_images)
            .where(id: args[:upload_ids])
            .find_in_batches do |uploads|
              uploads.each do |upload|
                begin
                  Discourse.store.update_upload_ACL(upload, optimized_images_preloaded: true)
                rescue => err
                  Discourse.warn_exception(
                    err,
                    message: "Failed to update upload ACL",
                    env: {
                      upload_id: upload.id,
                      filename: upload.original_filename,
                    },
                  )
                end
              end
            end
          Rails.logger.warn(
            "Completed syncing ACL for upload ids in #{time}. IDs: #{args[:upload_ids].join(", ")}",
          )
        end
    end
  end
end
