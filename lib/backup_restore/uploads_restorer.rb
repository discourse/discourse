# frozen_string_literal: true

module BackupRestore
  UploadsRestoreError = Class.new(RuntimeError)

  class UploadsRestorer
    delegate :log, to: :@logger, private: true

    def initialize(logger)
      @logger = logger
    end

    def restore(tmp_directory)
      upload_directories = Dir.glob(File.join(tmp_directory, "uploads", "*"))
        .reject { |path| File.basename(path).start_with?("PaxHeaders") }

      if upload_directories.count > 1
        raise UploadsRestoreError.new("Could not find uploads, because the uploads " \
          "directory contains multiple folders.")
      end

      @tmp_uploads_path = upload_directories.first
      return if @tmp_uploads_path.blank?

      @previous_db_name = BackupMetadata.value_for("db_name") || File.basename(@tmp_uploads_path)
      @current_db_name = RailsMultisite::ConnectionManagement.current_db
      backup_contains_optimized_images = File.exist?(File.join(@tmp_uploads_path, "optimized"))

      remap_uploads
      restore_uploads

      generate_optimized_images unless backup_contains_optimized_images
      rebake_posts_with_uploads
    end

    protected

    def restore_uploads
      store = Discourse.store

      if !store.respond_to?(:copy_from)
        # a FileStore implementation from a plugin might not support this method, so raise a helpful error
        store_name = Discourse.store.class.name
        raise UploadsRestoreError.new("The current file store (#{store_name}) does not support restoring uploads.")
      end

      log "Restoring uploads, this may take a while..."
      store.copy_from(@tmp_uploads_path)
    end

    # Remaps upload URLs depending on old and new configuration.
    # URLs of uploads differ a little bit between local uploads and uploads stored on S3.
    # Multisites are another reason why URLs can be different.
    #
    # Examples:
    #   * regular site, local storage
    #     /uploads/default/original/1X/63b76551662ccea1a594e161c37dd35188d77657.jpeg
    #
    #   * regular site, S3
    #     //bucket-name.s3.dualstack.us-west-2.amazonaws.com/original/1X/63b76551662ccea1a594e161c37dd35188d77657.jpeg
    #
    #   * multisite, local storage
    #     /uploads/<site-name>/original/1X/63b76551662ccea1a594e161c37dd35188d77657.jpeg
    #
    #   * multisite, S3
    #     //bucket-name.s3.dualstack.us-west-2.amazonaws.com/uploads/<site-name>/original/1X/63b76551662ccea1a594e161c37dd35188d77657.jpeg
    def remap_uploads
      log "Remapping uploads..."

      was_multisite = BackupMetadata.value_for("multisite") == "t"
      upload_path = "/#{Discourse.store.upload_path}/"
      uploads_folder = was_multisite ? "/" : upload_path

      if (old_base_url = BackupMetadata.value_for("base_url")) && old_base_url != Discourse.base_url
        remap(old_base_url, Discourse.base_url)
      end

      current_s3_base_url = SiteSetting::Upload.enable_s3_uploads ? SiteSetting::Upload.s3_base_url : nil
      if (old_s3_base_url = BackupMetadata.value_for("s3_base_url")) && old_s3_base_url != current_s3_base_url
        remap("#{old_s3_base_url}/", uploads_folder)
      end

      current_s3_cdn_url = SiteSetting::Upload.enable_s3_uploads ? SiteSetting::Upload.s3_cdn_url : nil
      if (old_s3_cdn_url = BackupMetadata.value_for("s3_cdn_url")) && old_s3_cdn_url != current_s3_cdn_url
        base_url = current_s3_cdn_url || Discourse.base_url
        remap("#{old_s3_cdn_url}/", UrlHelper.schemaless("#{base_url}#{uploads_folder}"))

        old_host = URI.parse(old_s3_cdn_url).host
        new_host = URI.parse(base_url).host
        remap(old_host, new_host) if old_host != new_host
      end

      if (old_cdn_url = BackupMetadata.value_for("cdn_url")) && old_cdn_url != Discourse.asset_host
        base_url = Discourse.asset_host || Discourse.base_url
        remap("#{old_cdn_url}/", UrlHelper.schemaless("#{base_url}/"))

        old_host = URI.parse(old_cdn_url).host
        new_host = URI.parse(base_url).host
        remap(old_host, new_host) if old_host != new_host
      end

      if @previous_db_name != @current_db_name
        remap("/uploads/#{@previous_db_name}/", upload_path)
      end

    rescue => ex
      log "Something went wrong while remapping uploads.", ex
    end

    def remap(from, to)
      log "Remapping '#{from}' to '#{to}'"
      DbHelper.remap(from, to, verbose: true, excluded_tables: ["backup_metadata"])
    end

    def generate_optimized_images
      log "Optimizing site icons..."
      DB.exec("TRUNCATE TABLE optimized_images")
      SiteIconManager.ensure_optimized!

      User.where("uploaded_avatar_id IS NOT NULL").find_each do |user|
        Jobs.enqueue(:create_avatar_thumbnails, upload_id: user.uploaded_avatar_id)
      end
    end

    def rebake_posts_with_uploads
      log 'Posts will be rebaked by a background job in sidekiq. You will see missing images until that has completed.'
      log 'You can expedite the process by manually running "rake posts:rebake_uncooked_posts"'

      DB.exec(<<~SQL)
        UPDATE posts
        SET baked_version = NULL
        WHERE id IN (SELECT post_id FROM post_uploads)
      SQL
    end
  end
end
