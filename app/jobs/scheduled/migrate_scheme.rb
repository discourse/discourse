module Jobs

  class MigrateScheme < Jobs::Scheduled
    every 10.minutes
    sidekiq_options retry: false

    MIGRATE_SCHEME_KEY ||= "migrate_to_new_scheme"

    def execute(args)
      begin
        return unless SiteSetting.migrate_to_new_scheme
        return if $redis.exists(MIGRATE_SCHEME_KEY)

        # use a mutex to make sure this job is only run once
        DistributedMutex.synchronize(MIGRATE_SCHEME_KEY) do
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
      rescue => e
        puts e.message
        puts e.backtrace.join("\n")
      end
    end

  end

end
