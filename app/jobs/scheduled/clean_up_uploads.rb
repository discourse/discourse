# frozen_string_literal: true

module Jobs
  class CleanUpUploads < ::Jobs::Scheduled
    every 1.hour

    def execute(args)
      grace_period = [SiteSetting.clean_orphan_uploads_grace_period_hours, 1].max

      # always remove invalid upload records
      Upload
        .by_users
        .where("retain_hours IS NULL OR created_at < current_timestamp - interval '1 hour' * retain_hours")
        .where("created_at < ?", grace_period.hour.ago)
        .where(url: "")
        .find_each(&:destroy!)

      return unless SiteSetting.clean_up_uploads?

      if c = last_cleanup
        return if (Time.zone.now.to_i - c) < (grace_period / 2).hours
      end

      base_url = Discourse.store.internal? ? Discourse.store.relative_base_url : Discourse.store.absolute_base_url
      s3_hostname = URI.parse(base_url).hostname
      s3_cdn_hostname = URI.parse(SiteSetting.Upload.s3_cdn_url || "").hostname

      result = Upload.by_users
        .where("uploads.retain_hours IS NULL OR uploads.created_at < current_timestamp - interval '1 hour' * uploads.retain_hours")
        .where("uploads.created_at < ?", grace_period.hour.ago)
        .where("uploads.access_control_post_id IS NULL")
        .joins("LEFT JOIN post_uploads pu ON pu.upload_id = uploads.id")
        .where("pu.upload_id IS NULL")
        .with_no_non_post_relations

      result.find_each do |upload|
        if upload.sha1.present?
          encoded_sha = Base62.encode(upload.sha1.hex)
          next if ReviewableQueuedPost.pending.where("payload->>'raw' LIKE '%#{upload.sha1}%' OR payload->>'raw' LIKE '%#{encoded_sha}%'").exists?
          next if Draft.where("data LIKE '%#{upload.sha1}%' OR data LIKE '%#{encoded_sha}%'").exists?
          next if UserProfile.where("bio_raw LIKE '%#{upload.sha1}%' OR bio_raw LIKE '%#{encoded_sha}%'").exists?
          if defined?(ChatMessage)
            # TODO after May 2022 - remove this. No longer needed as chat uploads are in a table
            next if ChatMessage.where("message LIKE ? OR message LIKE ?", "%#{upload.sha1}%", "%#{encoded_sha}%").exists?
          end

          if defined?(ChatUpload)
            next if ChatUpload.where(upload: upload).exists?
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
