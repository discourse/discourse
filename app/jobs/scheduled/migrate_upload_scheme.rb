# frozen_string_literal: true

module Jobs

  class MigrateUploadScheme < ::Jobs::Scheduled
    every 10.minutes
    sidekiq_options retry: false

    def execute(args)
      return unless SiteSetting.migrate_to_new_scheme

      # clean up failed uploads
      Upload.where("created_at < ?", 1.hour.ago)
        .where("LENGTH(COALESCE(url, '')) = 0")
        .find_each do |upload|

        upload.destroy!
      end

      # migrate uploads to new scheme
      problems = Upload.migrate_to_new_scheme(limit: 50)

      problems.each do |hash|
        upload_id = hash[:upload].id
        Discourse.handle_job_exception(hash[:ex], error_context(args, "Migrating upload id #{upload_id}", upload_id: upload_id))
      end

      # clean up failed optimized images
      OptimizedImage
        .where("LENGTH(COALESCE(url, '')) = 0")
        .find_each do |optimized_image|

        optimized_image.destroy!
      end

      # Clean up orphan optimized images
      OptimizedImage
        .joins("LEFT JOIN uploads ON optimized_images.upload_id = uploads.id")
        .where("uploads.id IS NULL")
        .find_each do |optimized_image|

        optimized_image.destroy!
      end

      # Clean up optimized images that needs to be regenerated
      OptimizedImage.joins(:upload)
        .where("optimized_images.url NOT LIKE '%/optimized/_X/%'")
        .where("uploads.url LIKE '%/original/_X/%'")
        .limit(50)
        .find_each do |optimized_image|

        upload = optimized_image.upload
        optimized_image.destroy!
        upload.rebake_posts_on_old_scheme
      end
    end

  end

end
