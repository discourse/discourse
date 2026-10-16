# frozen_string_literal: true

require "uri"
require "mini_mime"
require "file_store/base_store"
require "s3_helper"
require "file_helper"
require "file_store/object_storage/s3"

module FileStore
  class S3Store < BaseStore
    TOMBSTONE_PREFIX = "tombstone/"

    # Legacy callers may depend on SDK response objects. Core uses object_storage.
    delegate :abort_multipart,
             :presign_multipart_part,
             :list_multipart_parts,
             :complete_multipart,
             to: :s3_helper

    def initialize(s3_helper = nil, object_storage: nil)
      @s3_helper = s3_helper
      @object_storage = object_storage
    end

    def object_storage
      @object_storage ||= ObjectStorage::S3.new(s3_helper)
    end

    def s3_helper
      @s3_helper ||=
        S3Helper.new(
          s3_bucket,
          Rails.configuration.multisite ? multisite_tombstone_prefix : TOMBSTONE_PREFIX,
          use_accelerate_endpoint: SiteSetting.Upload.enable_s3_transfer_acceleration,
        )
    end

    def store_upload(file, upload, content_type = nil)
      upload.url = nil
      path = get_path_for_upload(upload)
      url, upload.etag =
        store_file(
          file,
          path,
          filename: upload.original_filename,
          content_type: content_type,
          cache_locally: true,
          private: upload.secure?,
          upload_id: upload.id,
        )
      url
    end

    def move_existing_stored_upload(existing_external_upload_key:, upload: nil, content_type: nil)
      upload.url = nil
      path = get_path_for_upload(upload)
      url, upload.etag =
        store_file(
          nil,
          path,
          filename: upload.original_filename,
          content_type: content_type,
          cache_locally: false,
          private: upload.secure?,
          move_existing: true,
          existing_external_upload_key: existing_external_upload_key,
        )
      url
    end

    def store_optimized_image(file, optimized_image, content_type = nil, secure: false)
      optimized_image.url = nil
      path = get_path_for_optimized_image(optimized_image)
      url, optimized_image.etag =
        store_file(file, path, content_type: content_type, private: secure)
      url
    end

    # File is an actual Tempfile on disk
    #
    # An existing_external_upload_key is given for cases where move_existing is specified.
    # This is an object already uploaded directly to S3 that we are now moving
    # to its final resting place with the correct sha and key.
    #
    # options
    #   - filename
    #   - content_type
    #   - cache_locally
    #   - move_existing
    #   - private
    #   - existing_external_upload_key
    def store_file(file, path, opts = {})
      path = path.dup

      filename = opts[:filename].presence || File.basename(path)
      # cache file locally when needed
      cache_file(file, File.basename(path)) if opts[:cache_locally]

      cache_control = "max-age=#{SiteSetting.s3_max_age}, public, immutable"
      if SiteSetting.s3_stale_while_revalidate != SiteSetting.defaults[:s3_stale_while_revalidate]
        cache_control =
          "#{cache_control}, stale-while-revalidate=#{SiteSetting.s3_stale_while_revalidate}"
      end

      options = {
        cache_control: cache_control,
        content_type:
          opts[:content_type].presence || MiniMime.lookup_by_filename(filename)&.content_type,
      }

      # Only serve inline for allowlisted safe file types (non-SVG images and PDFs)
      # to prevent XSS via HTML/XML/SVG uploads. All other files force download.
      # See https://github.com/discourse/discourse/commit/31e31ef44973dc4daaee2f010d71588ea5873b53
      options[:content_disposition] = self.class.content_disposition_for(filename)

      path.prepend(File.join(upload_path, "/")) if Rails.configuration.multisite

      # if this fails, it will throw an exception
      if opts[:move_existing] && opts[:existing_external_upload_key]
        original_path = opts[:existing_external_upload_key]
        result =
          object_storage.copy(
            original_path,
            path,
            visibility: opts[:private] ? :private : :public,
            headers: options,
            replace_metadata: true,
          )
        delete_file(original_path)
      else
        result =
          object_storage.upload(
            file,
            path,
            visibility: opts[:private] ? :private : :public,
            headers: options,
          )
      end

      # return the upload url and etag
      [File.join(absolute_base_url, result.key), result.etag]
    rescue ObjectStorage::Error => error
      ObjectStorage::S3.raise_legacy(error)
    end

    def delete_file(path)
      # delete the object outright without moving to tombstone,
      # not recommended for most use cases
      object_storage.delete(path, exact: true)
    rescue ObjectStorage::Error => error
      ObjectStorage::S3.raise_legacy(error)
    end

    def remove_file(url, path)
      return unless has_been_uploaded?(url)
      object_storage.remove(path)
    rescue ObjectStorage::Error => error
      ObjectStorage::S3.raise_legacy(error)
    end

    def copy_file(source:, destination:, secure:)
      result = object_storage.copy(source, destination, visibility: secure ? :private : :public)
      [result.key, result.etag]
    rescue ObjectStorage::Error => error
      ObjectStorage::S3.raise_legacy(error)
    end

    def has_been_uploaded?(url)
      return false if url.blank?

      begin
        parsed_url = URI.parse(UrlHelper.encode(url))
      rescue StandardError
        # There are many exceptions possible here including Addressable::URI:: exceptions
        # and URI:: exceptions, catch all may seem wide, but it makes no sense to raise ever
        # on an invalid url here
        return false
      end

      base_hostname = URI.parse(absolute_base_url).hostname
      if url[base_hostname]
        # if the hostnames match it means the upload is in the same
        # bucket on s3. however, the bucket folder path may differ in
        # some cases, and we do not want to assume the url is uploaded
        # here. e.g. the path of the current site could be /prod and the
        # other site could be /staging
        if s3_bucket_folder_path.present?
          return parsed_url.path.starts_with?("/#{s3_bucket_folder_path}")
        else
          return true
        end
      end

      return false if SiteSetting.Upload.s3_cdn_url.blank?

      s3_cdn_url = URI.parse(SiteSetting.Upload.s3_cdn_url || "")
      cdn_hostname = s3_cdn_url.hostname

      if cdn_hostname.presence && url[cdn_hostname] &&
           (s3_cdn_url.path.blank? || parsed_url.path.starts_with?(s3_cdn_url.path))
        return true
      end
      false
    end

    def s3_bucket_folder_path
      S3Helper.get_bucket_and_folder_path(s3_bucket)[1]
    end

    def s3_bucket_name
      S3Helper.get_bucket_and_folder_path(s3_bucket)[0]
    end

    def absolute_base_url
      @absolute_base_url ||= SiteSetting.Upload.absolute_base_url
    end

    def s3_upload_host
      SiteSetting.Upload.s3_cdn_url.presence || "https:#{absolute_base_url}"
    end

    def external?
      true
    end

    def purge_tombstone(grace_period)
      s3_helper.update_tombstone_lifecycle(grace_period)
    end

    def multisite_tombstone_prefix
      File.join("uploads", "tombstone", RailsMultisite::ConnectionManagement.current_db, "/")
    end

    def download_url(upload)
      return unless upload
      "#{upload.short_path}?dl=1"
    end

    def path_for(upload)
      url = upload&.url
      FileStore::LocalStore.new.path_for(upload) if url && url[%r{\A/[^/]}]
    end

    def url_for(upload, force_download: false)
      if upload.secure? || force_download
        presigned_get_url(
          get_upload_key(upload),
          force_download: force_download,
          filename: upload.original_filename,
        )
      elsif SiteSetting.s3_use_cdn_url_for_all_uploads
        cdn_url(upload.url)
      else
        upload.url
      end
    end

    def cdn_url(url)
      return url if SiteSetting.Upload.s3_cdn_url.blank?
      schema = url[%r{\A(https?:)?//}, 1]
      folder = s3_bucket_folder_path.nil? ? "" : "#{s3_bucket_folder_path}/"
      url.sub(
        File.join("#{schema}#{absolute_base_url}", folder),
        File.join(SiteSetting.Upload.s3_cdn_url, "/"),
      )
    end

    def signed_url_for_path(
      path,
      expires_in: SiteSetting.s3_presigned_get_url_expires_after_seconds,
      force_download: false,
      filename: nil,
      include_content_disposition:
    )
      key = path.sub(absolute_base_url + "/", "")

      presigned_get_url(
        key,
        expires_in:,
        force_download:,
        filename: include_content_disposition ? (filename || File.basename(path)) : nil,
      )
    end

    def signed_request_for_temporary_upload(
      file_name,
      expires_in: S3Helper::UPLOAD_URL_EXPIRES_AFTER_SECONDS,
      metadata: {}
    )
      request = prepare_direct_upload(file_name, expires_in:, metadata:)
      [request.url, request.headers]
    rescue ObjectStorage::Error => error
      ObjectStorage::S3.raise_legacy(error)
    end

    def prepare_direct_upload(
      file_name,
      expires_in: S3Helper::UPLOAD_URL_EXPIRES_AFTER_SECONDS,
      metadata: {}
    )
      key = temporary_upload_path(file_name)

      object_storage.upload_request(key, visibility: :private, expires_in: expires_in, metadata:)
    end

    def temporary_upload_path(file_name)
      folder_prefix =
        s3_bucket_folder_path.nil? ? upload_path : File.join(s3_bucket_folder_path, upload_path)
      FileStore::BaseStore.temporary_upload_path(file_name, folder_prefix: folder_prefix)
    end

    def object_from_path(path)
      s3_helper.object(path)
    end

    def cache_avatar(avatar, user_id)
      source = avatar.url.sub(absolute_base_url + "/", "")
      destination = avatar_template(avatar, user_id).sub(absolute_base_url + "/", "")
      result = object_storage.copy(source, destination, visibility: :bucket_default)
      [result.key, result.etag]
    rescue ObjectStorage::Error => error
      ObjectStorage::S3.raise_legacy(error)
    end

    def avatar_template(avatar, user_id)
      UserAvatar.external_avatar_url(user_id, avatar.upload_id, avatar.width)
    end

    def s3_bucket
      if SiteSetting.Upload.s3_upload_bucket.blank?
        raise Discourse::SiteSettingMissing.new("s3_upload_bucket")
      end
      SiteSetting.Upload.s3_upload_bucket.downcase
    end

    def stat_file(key)
      object_storage.stat(key)
    rescue ObjectStorage::Error => error
      ObjectStorage::S3.raise_legacy(error)
    end

    def remove_temporary_file(key)
      object_storage.remove(key, tombstone: false)
    rescue ObjectStorage::Error => error
      ObjectStorage::S3.raise_legacy(error)
    end

    def list_missing_uploads(skip_optimized: false)
      if s3_inventory_bucket = SiteSetting.s3_inventory_bucket
        s3_options = {}

        if (s3_inventory_bucket_region = SiteSetting.s3_inventory_bucket_region).present?
          s3_options[:region] = s3_inventory_bucket_region
        end

        S3Inventory.new(:upload, s3_inventory_bucket:, s3_options:).backfill_etags_and_list_missing

        unless skip_optimized
          S3Inventory.new(:optimized, s3_inventory_bucket:).backfill_etags_and_list_missing
        end
      else
        list_missing(Upload.by_users, "original/")
        list_missing(OptimizedImage, "optimized/") unless skip_optimized
      end
    rescue ObjectStorage::Error => error
      ObjectStorage::S3.raise_legacy(error)
    end

    def update_upload_access_control(upload, remove_existing_acl: false)
      key = get_upload_key(upload)
      update_access_control(key, upload.secure?, remove_existing_acl:)

      upload.optimized_images.each do |optimized_image|
        update_optimized_image_access_control(
          optimized_image,
          secure: upload.secure,
          remove_existing_acl:,
        )
      end

      true
    end

    def update_optimized_image_access_control(
      optimized_image,
      secure: false,
      remove_existing_acl: false
    )
      optimized_image_key = get_path_for_optimized_image(optimized_image)
      optimized_image_key.prepend(File.join(upload_path, "/")) if Rails.configuration.multisite
      update_access_control(optimized_image_key, secure, remove_existing_acl:)
    end

    def update_file_access_control(file_path, secure, remove_existing_acl: false)
      update_access_control(file_path, secure, remove_existing_acl:)
    end

    def download_file(upload, destination_path)
      key = get_upload_key(upload)
      begin
        object_storage.download(key, destination_path)
      rescue ObjectStorage::Error => error
        # Preserve the legacy store API while the adapter exposes typed failures.
        raise error.message
      rescue => error
        raise "Failed to download #{key} because #{error.message.presence || error.class}"
      end
    end

    def copy_from(source_path)
      local_store = FileStore::LocalStore.new
      public_upload_path = File.join(local_store.public_dir, local_store.upload_path)

      # The migration to S3 and lots of other code expects files to exist in public/uploads,
      # so lets move them there before executing the migration.
      if public_upload_path != source_path
        if Dir.exist?(public_upload_path)
          old_upload_path = "#{public_upload_path}_#{SecureRandom.hex}"
          FileUtils.mv(public_upload_path, old_upload_path)
        end
      end

      FileUtils.mkdir_p(File.expand_path("..", public_upload_path))
      FileUtils.symlink(source_path, public_upload_path)

      FileStore::ToS3Migration.new(
        s3_options: FileStore::ToS3Migration.s3_options_from_site_settings,
        migrate_to_multisite: Rails.configuration.multisite,
      ).migrate
    ensure
      FileUtils.rm(public_upload_path) if File.symlink?(public_upload_path)
      FileUtils.mv(old_upload_path, public_upload_path) if old_upload_path
    end

    def create_multipart(file_name, content_type, metadata: {})
      prepare_multipart_upload(file_name, content_type, metadata:)
    rescue ObjectStorage::Error => error
      ObjectStorage::S3.raise_legacy(error)
    end

    def prepare_multipart_upload(file_name, content_type, metadata: {})
      key = temporary_upload_path(file_name)
      object_storage.create_multipart(key, content_type, metadata:, visibility: :private)
    end

    # The following are canned ACLs defined by AWS S3 and not some generic value which we decide to use.
    # https://docs.aws.amazon.com/AmazonS3/latest/userguide/acl-overview.html
    CANNED_ACL_PUBLIC_READ = "public-read"
    CANNED_ACL_PRIVATE = "private"

    def self.acl_option_value(secure:)
      ObjectStorage::S3.acl_for(secure ? :private : :public)
    end

    def acl_option_value(secure:)
      self.class.acl_option_value(secure:)
    end

    def self.visibility_tagging_option_value(secure:, encode_form: true)
      ObjectStorage::S3.tags_for(secure ? :private : :public, encode_form:)
    end

    def self.default_s3_options(secure:)
      ObjectStorage::S3.visibility_options(secure ? :private : :public)
    end

    def default_s3_options(secure:)
      self.class.default_s3_options(secure:)
    end

    # S3 limits total request header/metadata size to 2 KB. Content-Disposition
    # includes the filename twice (filename= and filename*=UTF-8''), so we
    # limit the full header to 1600 bytes to stay within that budget.
    MAX_CONTENT_DISPOSITION_BYTES = 1_600

    def self.content_disposition_for(filename, disposition: nil)
      disposition ||= FileHelper.is_inline_safe?(filename) ? "inline" : "attachment"
      return "" if filename.blank?

      header = ActionDispatch::Http::ContentDisposition.format(disposition:, filename:)
      return header if header.bytesize <= MAX_CONTENT_DISPOSITION_BYTES

      extension = File.extname(filename)
      basename = File.basename(filename, extension)

      # Binary search for the longest basename that fits within the limit
      low = 1
      high = basename.length

      while low < high
        mid = (low + high + 1) / 2
        candidate = "#{basename[0...mid]}#{extension}"
        test_header =
          ActionDispatch::Http::ContentDisposition.format(disposition:, filename: candidate)
        if test_header.bytesize <= MAX_CONTENT_DISPOSITION_BYTES
          low = mid
        else
          high = mid - 1
        end
      end

      ActionDispatch::Http::ContentDisposition.format(
        disposition:,
        filename: "#{basename[0...low]}#{extension}",
      )
    end

    private

    def presigned_get_url(
      url,
      force_download: false,
      filename: false,
      expires_in: SiteSetting.s3_presigned_get_url_expires_after_seconds
    )
      content_disposition = nil

      if filename
        disposition =
          (force_download || !FileHelper.is_inline_safe?(filename)) ? "attachment" : "inline"
        content_disposition =
          ActionDispatch::Http::ContentDisposition.format(disposition:, filename:)
      end

      object_storage.download_url(url, expires_in:, content_disposition:)
    rescue ObjectStorage::Error => error
      ObjectStorage::S3.raise_legacy(error)
    end

    def get_upload_key(upload)
      if Rails.configuration.multisite
        File.join(upload_path, "/", get_path_for_upload(upload))
      else
        get_path_for_upload(upload)
      end
    end

    def update_access_control(key, secure, remove_existing_acl: false)
      object_storage.set_visibility(
        key,
        visibility: secure ? :private : :public,
        reset_existing_permissions: remove_existing_acl,
      )
    rescue ObjectStorage::Error => error
      ObjectStorage::S3.raise_legacy(error)
    end

    def list_missing(model, prefix)
      connection = ActiveRecord::Base.connection.raw_connection
      connection.exec("CREATE TEMP TABLE verified_ids(val integer PRIMARY KEY)")
      marker = nil
      files = object_storage.list(prefix, marker:)

      while files.count > 0
        verified_ids = []

        files.each do |f|
          id = model.where("url LIKE '%#{f.key}' AND etag = '#{f.etag}'").pick(:id)
          verified_ids << id if id.present?
          marker = f.key
        end

        verified_id_clause =
          verified_ids.map { |id| "('#{PG::Connection.escape_string(id.to_s)}')" }.join(",")
        connection.exec("INSERT INTO verified_ids VALUES #{verified_id_clause}")
        files = object_storage.list(prefix, marker:)
      end

      missing_uploads =
        model.joins("LEFT JOIN verified_ids ON verified_ids.val = id").where(
          "verified_ids.val IS NULL",
        )
      missing_count = missing_uploads.count

      if missing_count > 0
        missing_uploads.find_each { |upload| puts upload.url }

        puts "#{missing_count} of #{model.count} #{model.name.underscore.pluralize} are missing"
      end
    ensure
      connection.exec("DROP TABLE verified_ids") unless connection.nil?
    end
  end
end
