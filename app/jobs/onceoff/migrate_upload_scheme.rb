module Jobs

  class MigrateUploadScheme < Jobs::Onceoff

    def execute_onceoff(args)
      return unless SiteSetting.migrate_to_new_scheme

      # clean up failed uploads
      Upload.where("created_at < ?", 1.hour.ago)
            .where("LENGTH(COALESCE(url, '')) = 0")
            .destroy_all

      # migrate uploads to new scheme
      problems = Upload.migrate_to_new_scheme
      problems.each do |hash|
        upload_id = hash[:upload].id
        Discourse.handle_job_exception(hash[:ex], error_context(args, "Migrating upload id #{upload_id}", upload_id: upload_id))
      end

      # clean up failed optimized images
      OptimizedImage.where("LENGTH(COALESCE(url, '')) = 0").destroy_all
      # Clean up orphan optimized images
      OptimizedImage.where("upload_id NOT IN (SELECT id FROM uploads)").destroy_all

      # migrate optimized_images to new scheme
      problems = OptimizedImage.migrate_to_new_scheme
      problems.each do |hash|
        optimized_image_id = hash[:optimized_image].id
        Discourse.handle_job_exception(hash[:ex], error_context(args, "Migrating optimized_image id #{optimized_image_id}", optimized_image_id: optimized_image_id))
      end
    end

  end

end
