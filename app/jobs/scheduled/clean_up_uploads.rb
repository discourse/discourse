# frozen_string_literal: true

module Jobs
  class CleanUpUploads < ::Jobs::Scheduled
    every 1.hour

    def execute(args)
      grace_period = [SiteSetting.clean_orphan_uploads_grace_period_hours, 1].max

      # Always remove invalid upload records regardless of clean_up_uploads setting.
      Upload
        .by_users
        .where(
          "retain_hours IS NULL OR created_at < current_timestamp - interval '1 hour' * retain_hours",
        )
        .where("created_at < ?", grace_period.hour.ago)
        .where(url: "")
        .find_each(&:destroy!)

      return unless SiteSetting.clean_up_uploads?

      # Do nothing if the last cleanup was run too recently.
      last_cleanup_timestamp = last_cleanup
      if last_cleanup_timestamp.present? &&
           (Time.zone.now.to_i - last_cleanup_timestamp) < (grace_period / 2).hours
        return
      end

      result = Upload.by_users
      Upload.unused_callbacks&.each { |handler| result = handler.call(result) }
      result =
        result
          .where(
            "uploads.retain_hours IS NULL OR uploads.created_at < current_timestamp - interval '1 hour' * uploads.retain_hours",
          )
          .where("uploads.created_at < ?", grace_period.hour.ago) # Don't remove any secure uploads.
          .where("uploads.access_control_post_id IS NULL")
          .joins(
            "LEFT JOIN upload_references ON upload_references.upload_id = uploads.id",
          ) # Don't remove any uploads linked to an UploadReference.
          .where("upload_references.upload_id IS NULL")
          .with_no_non_post_relations

      result.find_each do |upload|
        next if Upload.in_use_callbacks&.any? { |callback| callback.call(upload) }
        upload.sha1.present? ? upload.destroy : upload.delete
      end

      ExternalUploadStub.cleanup!

      self.last_cleanup = Time.zone.now.to_i
    end

    def last_cleanup=(timestamp)
      Discourse.redis.setex(last_cleanup_key, 7.days.to_i, timestamp.to_s)
    end

    def last_cleanup
      timestamp = Discourse.redis.get(last_cleanup_key)
      timestamp ? timestamp.to_i : timestamp
    end

    def reset_last_cleanup!
      Discourse.redis.del(last_cleanup_key)
    end

    protected

    def last_cleanup_key
      "LAST_UPLOAD_CLEANUP"
    end
  end
end
