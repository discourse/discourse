# frozen_string_literal: true

require "aws-sdk-s3"

module FileStore
  ToS3MigrationError = Class.new(RuntimeError)

  class ToS3Migration
    MISSING_UPLOADS_RAKE_TASK_NAME = "posts:missing_uploads"
    UPLOAD_CONCURRENCY = 20

    def initialize(s3_options:, dry_run: false, migrate_to_multisite: false)
      @s3_bucket = s3_options[:bucket]
      @s3_client_options = s3_options[:client_options]
      @dry_run = dry_run
      @migrate_to_multisite = migrate_to_multisite
      @current_db = RailsMultisite::ConnectionManagement.current_db
    end

    def self.s3_options_from_site_settings
      {
        client_options: S3Helper.s3_options(SiteSetting),
        bucket: SiteSetting.Upload.s3_upload_bucket,
      }
    end

    def self.s3_options_from_env
      if ENV["DISCOURSE_S3_BUCKET"].blank? || ENV["DISCOURSE_S3_REGION"].blank? ||
           !(
             (
               ENV["DISCOURSE_S3_ACCESS_KEY_ID"].present? &&
                 ENV["DISCOURSE_S3_SECRET_ACCESS_KEY"].present?
             ) || ENV["DISCOURSE_S3_USE_IAM_PROFILE"].present?
           )
        raise ToS3MigrationError.new(<<~TEXT)
          Please provide the following environment variables:
            - DISCOURSE_S3_BUCKET
            - DISCOURSE_S3_REGION
            and either
            - DISCOURSE_S3_ACCESS_KEY_ID
            - DISCOURSE_S3_SECRET_ACCESS_KEY
            or
            - DISCOURSE_S3_USE_IAM_PROFILE
        TEXT
      end

      opts = { region: ENV["DISCOURSE_S3_REGION"] }
      opts[:endpoint] = ENV["DISCOURSE_S3_ENDPOINT"] if ENV["DISCOURSE_S3_ENDPOINT"].present?

      if ENV["DISCOURSE_S3_USE_IAM_PROFILE"].blank?
        opts[:access_key_id] = ENV["DISCOURSE_S3_ACCESS_KEY_ID"]
        opts[:secret_access_key] = ENV["DISCOURSE_S3_SECRET_ACCESS_KEY"]
      end

      { client_options: opts, bucket: ENV["DISCOURSE_S3_BUCKET"] }
    end

    def migrate
      migrate_to_s3
    end

    def migration_successful?(should_raise: false)
      success = true

      failure_message = "S3 migration failed for db '#{@current_db}'."
      prefix = @migrate_to_multisite ? "uploads/#{@current_db}/original/" : "original/"

      base_url = File.join(SiteSetting.Upload.s3_base_url, prefix)
      count = Upload.by_users.where("url NOT LIKE '#{base_url}%'").count
      if count > 0
        error_message =
          "#{count} of #{Upload.count} uploads are not migrated to S3. #{failure_message}"
        raise_or_log(error_message, should_raise)
        success = false
      end

      cdn_path = SiteSetting.cdn_path("/uploads/#{@current_db}/original").sub(/https?:/, "")
      count = Post.where("cooked LIKE '%#{cdn_path}%'").count
      if count > 0
        error_message = "#{count} posts are not remapped to new S3 upload URL. #{failure_message}"
        raise_or_log(error_message, should_raise)
        success = false
      end

      unless Rake::Task.task_defined?(MISSING_UPLOADS_RAKE_TASK_NAME)
        Discourse::Application.load_tasks
      end
      Rake::Task[MISSING_UPLOADS_RAKE_TASK_NAME]
      count = DB.query_single(<<~SQL, Post::MISSING_UPLOADS, Post::MISSING_UPLOADS_IGNORED).first
        SELECT COUNT(1)
        FROM posts p
        WHERE EXISTS (
          SELECT 1
          FROM post_custom_fields f
          WHERE f.post_id = p.id AND f.name = ?
        ) AND NOT EXISTS (
          SELECT 1
          FROM post_custom_fields f
          WHERE f.post_id = p.id AND f.name = ?
        )
      SQL
      if count > 0
        error_message = "rake posts:missing_uploads identified #{count} issues. #{failure_message}"
        raise_or_log(error_message, should_raise)
        success = false
      end

      count = Post.where("baked_version <> ? OR baked_version IS NULL", Post::BAKED_VERSION).count
      if count > 0
        log("#{count} posts still require rebaking and will be rebaked during regular job")
        if count > 100
          log(
            "To speed up migrations of posts we recommend you run 'rake posts:rebake_uncooked_posts'",
          )
        end
        success = false
      else
        log("No posts require rebaking")
      end

      success
    end

    protected

    def log(message)
      puts message
    end

    def raise_or_log(message, should_raise)
      if should_raise
        raise ToS3MigrationError.new(message)
      else
        log(message)
      end
    end

    def uploads_migrated_to_new_scheme?
      seeded_image_url = "uploads/#{@current_db}/original/_X/"
      !Upload.by_users.where("url NOT LIKE '//%' AND url NOT LIKE '/%#{seeded_image_url}%'").exists?
    end

    def migrate_to_s3
      # we don't want have migrated state, ensure we run all jobs here
      Jobs.run_immediately!

      log "*" * 30 + " DRY RUN " + "*" * 30 if @dry_run
      log "Migrating uploads to S3 for '#{@current_db}'..."

      if !uploads_migrated_to_new_scheme?
        log "Some uploads were not migrated to the new scheme. Running the migration, this may take a while..."
        SiteSetting.migrate_to_new_scheme = true
        Upload.migrate_to_new_scheme

        if !uploads_migrated_to_new_scheme?
          raise ToS3MigrationError.new(
                  "Some uploads could not be migrated to the new scheme. " \
                    "You need to fix this manually.",
                )
        end
      end

      bucket_has_folder_path = true if @s3_bucket.include? "/"
      public_directory = Rails.root.join("public").to_s

      s3 = Aws::S3::Client.new(@s3_client_options)

      if bucket_has_folder_path
        bucket, folder = S3Helper.get_bucket_and_folder_path(@s3_bucket)
        folder = File.join(folder, "/")
      else
        bucket, folder = @s3_bucket, ""
      end

      log "Uploading files to S3..."
      log " - Listing local files"

      local_files = []
      IO
        .popen("cd #{public_directory} && find uploads/#{@current_db}/original -type f")
        .each do |file|
          local_files << file.chomp
          putc "." if local_files.size % 1000 == 0
        end

      log " => #{local_files.size} files"
      log " - Listing S3 files"

      s3_objects = []
      prefix = @migrate_to_multisite ? "uploads/#{@current_db}/original/" : "original/"

      options = { bucket: bucket, prefix: folder + prefix }

      loop do
        response = s3.list_objects_v2(options)
        s3_objects.concat(response.contents)
        putc "."
        break if response.next_continuation_token.blank?
        options[:continuation_token] = response.next_continuation_token
      end

      log " => #{s3_objects.size} files"
      log " - Syncing files to S3"

      queue = Queue.new
      synced = 0
      failed = []

      lock = Mutex.new
      upload_threads =
        UPLOAD_CONCURRENCY.times.map do
          Thread.new do
            while obj = queue.pop
              opts_with_file = obj[:options].merge(body: File.open(obj[:path], "rb"))
              if s3.put_object(opts_with_file)
                putc "."
                lock.synchronize { synced += 1 }
              else
                putc "X"
                lock.synchronize { failed << obj[:path] }
              end
            end
          end
        end

      local_files.each do |file|
        path = File.join(public_directory, file)
        name = File.basename(path)
        content_md5 = Digest::MD5.file(path).base64digest
        key = file[file.index(prefix)..-1]
        key.prepend(folder) if bucket_has_folder_path
        original_path = file.sub("uploads/#{@current_db}", "")

        if (s3_object = s3_objects.find { |obj| obj.key.ends_with?(original_path) }) &&
             File.size(path) == s3_object.size
          next
        end

        options = {
          acl: SiteSetting.s3_use_acls ? "public-read" : nil,
          bucket: bucket,
          content_type: MiniMime.lookup_by_filename(name)&.content_type,
          content_md5: content_md5,
          key: key,
        }

        if !FileHelper.is_supported_image?(name)
          upload = Upload.find_by(url: "/#{file}")

          if upload&.original_filename
            options[:content_disposition] = ActionDispatch::Http::ContentDisposition.format(
              disposition: "attachment",
              filename: upload.original_filename,
            )
          end

          options[:acl] = "private" if upload&.secure
        elsif !FileHelper.is_inline_image?(name)
          upload = Upload.find_by(url: "/#{file}")
          options[:content_disposition] = ActionDispatch::Http::ContentDisposition.format(
            disposition: "attachment",
            filename: upload&.original_filename || name,
          )
        end

        if @dry_run
          log "#{file} => #{options[:key]}"
          synced += 1
        else
          queue << { path: path, options: options, content_md5: content_md5 }
        end
      end

      queue.close
      upload_threads.each(&:join)

      puts

      failure_message = "S3 migration failed for db '#{@current_db}'."

      if failed.size > 0
        log "Failed to upload #{failed.size} files"
        log failed.join("\n")
        raise failure_message
      elsif s3_objects.size + synced >= local_files.size
        log "Updating the URLs in the database..."

        from = "/uploads/#{@current_db}/original/"
        to = "#{SiteSetting.Upload.s3_base_url}/#{prefix}"

        if @dry_run
          log "REPLACING '#{from}' WITH '#{to}'"
        else
          DbHelper.remap(from, to, anchor_left: true)
        end

        [
          [
            "src=\"/uploads/#{@current_db}/original/(\\dX/(?:[a-f0-9]/)*[a-f0-9]{40}[a-z0-9\\.]*)",
            "src=\"#{SiteSetting.Upload.s3_base_url}/#{prefix}\\1",
          ],
          [
            "src='/uploads/#{@current_db}/original/(\\dX/(?:[a-f0-9]/)*[a-f0-9]{40}[a-z0-9\\.]*)",
            "src='#{SiteSetting.Upload.s3_base_url}/#{prefix}\\1",
          ],
          [
            "href=\"/uploads/#{@current_db}/original/(\\dX/(?:[a-f0-9]/)*[a-f0-9]{40}[a-z0-9\\.]*)",
            "href=\"#{SiteSetting.Upload.s3_base_url}/#{prefix}\\1",
          ],
          [
            "href='/uploads/#{@current_db}/original/(\\dX/(?:[a-f0-9]/)*[a-f0-9]{40}[a-z0-9\\.]*)",
            "href='#{SiteSetting.Upload.s3_base_url}/#{prefix}\\1",
          ],
          [
            "\\[img\\]/uploads/#{@current_db}/original/(\\dX/(?:[a-f0-9]/)*[a-f0-9]{40}[a-z0-9\\.]*)\\[/img\\]",
            "[img]#{SiteSetting.Upload.s3_base_url}/#{prefix}\\1[/img]",
          ],
        ].each do |from_url, to_url|
          if @dry_run
            log "REPLACING '#{from_url}' WITH '#{to_url}'"
          else
            DbHelper.regexp_replace(from_url, to_url)
          end
        end

        unless @dry_run
          # Legacy inline image format
          Post
            .where("raw LIKE '%![](/uploads/default/original/%)%'")
            .each do |post|
              regexp =
                /!\[\](\/uploads\/#{@current_db}\/original\/(\dX\/(?:[a-f0-9]\/)*[a-f0-9]{40}[a-z0-9\.]*))/

              post
                .raw
                .scan(regexp)
                .each do |upload_url, _|
                  upload = Upload.get_from_url(upload_url)
                  post.raw = post.raw.gsub("![](#{upload_url})", "![](#{upload.short_url})")
                end

              post.save!(validate: false)
            end
        end

        if Discourse.asset_host.present?
          # Uploads that were on local CDN will now be on S3 CDN
          from = "#{Discourse.asset_host}/uploads/#{@current_db}/original/"
          to = "#{SiteSetting.Upload.s3_cdn_url}/#{prefix}"

          if @dry_run
            log "REMAPPING '#{from}' TO '#{to}'"
          else
            DbHelper.remap(from, to)
          end
        end

        # Uploads that were on base hostname will now be on S3 CDN
        from = "#{Discourse.base_url}/uploads/#{@current_db}/original/"
        to = "#{SiteSetting.Upload.s3_cdn_url}/#{prefix}"

        if @dry_run
          log "REMAPPING '#{from}' TO '#{to}'"
        else
          DbHelper.remap(from, to)
        end

        unless @dry_run
          log "Removing old optimized images..."

          OptimizedImage
            .joins("LEFT JOIN uploads u ON optimized_images.upload_id = u.id")
            .where("u.id IS NOT NULL AND u.url LIKE '//%' AND optimized_images.url NOT LIKE '//%'")
            .delete_all

          log "Flagging all posts containing lightboxes for rebake..."

          count = Post.where("cooked LIKE '%class=\"lightbox\"%'").update_all(baked_version: nil)
          log "#{count} posts were flagged for a rebake"
        end
      end

      migration_successful?(should_raise: true)

      log "Done!"
    ensure
      Jobs.run_later!
    end
  end
end
