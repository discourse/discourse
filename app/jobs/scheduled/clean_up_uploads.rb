# frozen_string_literal: true

module Jobs
  class CleanUpUploads < ::Jobs::Scheduled
    every 1.hour

    def execute(args)
      grace_period = [SiteSetting.clean_orphan_uploads_grace_period_hours, 1].max

      # always remove invalid upload records
      Upload
        .by_users
        .where(
          "retain_hours IS NULL OR created_at < current_timestamp - interval '1 hour' * retain_hours",
        )
        .where("created_at < ?", grace_period.hour.ago)
        .where(url: "")
        .find_each(&:destroy!)

      return unless SiteSetting.clean_up_uploads?

      if c = last_cleanup
        return if (Time.zone.now.to_i - c) < (grace_period / 2).hours
      end

      base_url =
        (
          if Discourse.store.internal?
            Discourse.store.relative_base_url
          else
            Discourse.store.absolute_base_url
          end
        )
      s3_hostname = URI.parse(base_url).hostname
      s3_cdn_hostname = URI.parse(SiteSetting.Upload.s3_cdn_url || "").hostname

      result = Upload.by_users
      Upload.unused_callbacks&.each { |handler| result = handler.call(result) }
      result =
        result
          .where(
            "uploads.retain_hours IS NULL OR uploads.created_at < current_timestamp - interval '1 hour' * uploads.retain_hours",
          )
          .where("uploads.created_at < ?", grace_period.hour.ago)
          .where("uploads.access_control_post_id IS NULL")
          .joins("LEFT JOIN upload_references ON upload_references.upload_id = uploads.id")
          .where("upload_references.upload_id IS NULL")
          .with_no_non_post_relations

      result.find_each do |upload|
        next if Upload.in_use_callbacks&.any? { |callback| callback.call(upload) }

        if upload.sha1.present?
          # TODO: Remove this check after UploadReferences records were created
          encoded_sha = Base62.encode(upload.sha1.hex)
          if ReviewableQueuedPost
               .pending
               .where(
                 "payload->>'raw' LIKE ? OR payload->>'raw' LIKE ?",
                 "%#{upload.sha1}%",
                 "%#{encoded_sha}%",
               )
               .exists?
            next
          end
          if Draft.where(
               "data LIKE ? OR data LIKE ?",
               "%#{upload.sha1}%",
               "%#{encoded_sha}%",
             ).exists?
            next
          end
          if UserProfile.where(
               "bio_raw LIKE ? OR bio_raw LIKE ?",
               "%#{upload.sha1}%",
               "%#{encoded_sha}%",
             ).exists?
            next
          end

          upload.destroy
        else
          upload.delete
        end
      end

      ExternalUploadStub.cleanup!

      self.last_cleanup = Time.zone.now.to_i
    end

    def last_cleanup=(v)
      Discourse.redis.setex(last_cleanup_key, 7.days.to_i, v.to_s)
    end

    def last_cleanup
      v = Discourse.redis.get(last_cleanup_key)
      v ? v.to_i : v
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
