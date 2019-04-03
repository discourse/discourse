module Jobs

  class MigrateUploadScheme < Jobs::Scheduled
    every 10.minutes
    sidekiq_options retry: false

    def execute(args)
      return unless SiteSetting.migrate_to_new_scheme

      # clean up failed uploads
      Upload.where("created_at < ?", 1.hour.ago)
        .where("LENGTH(COALESCE(url, '')) = 0")
        .destroy_all

      # migrate uploads to new scheme
      problems = Upload.migrate_to_new_scheme(50)

      problems.each do |hash|
        upload_id = hash[:upload].id
        Discourse.handle_job_exception(hash[:ex], error_context(args, "Migrating upload id #{upload_id}", upload_id: upload_id))
      end

      # clean up failed optimized images
      OptimizedImage.where("LENGTH(COALESCE(url, '')) = 0").destroy_all
      # Clean up orphan optimized images
      OptimizedImage.where("upload_id NOT IN (SELECT id FROM uploads)").destroy_all

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

      Post.where("cooked LIKE '%<img %'").find_each do |post|
        missing = post.find_missing_uploads
        next if missing.blank?
  
        missing.each do |src|
          src.sub!("https://discourse-cdn-sjc1.com/mcneel", "")
          next unless src.split("/").length == 5
  
          source = "#{Discourse.store.public_dir}#{src}"
          if File.exists?(source)
            PostCustomField.create!(post_id: post.id, value: src, key: "pu_found")
            next
          end
  
          source = "#{Discourse.store.tombstone_dir}#{src}"
          if File.exists?(source)
            PostCustomField.create!(post_id: post.id, value: src, key: "pu_tombstone")
            next
          end
  
          PostCustomField.create!(post_id: post.id, value: src, key: "pu_missing")
        end
      end
    end

  end

end
