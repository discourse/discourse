# frozen_string_literal: true

require "uri"
require "mini_mime"
require "file_store/base_store"
require "s3_helper"
require "file_helper"

module FileStore
  class S3Store < BaseStore
    TOMBSTONE_PREFIX = "tombstone/"

    delegate :abort_multipart,
             :presign_multipart_part,
             :list_multipart_parts,
             :complete_multipart,
             to: :s3_helper

    def initialize(s3_helper = nil)
      @s3_helper = s3_helper
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
          private_acl: upload.secure?,
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
          private_acl: upload.secure?,
          move_existing: true,
          existing_external_upload_key: existing_external_upload_key,
        )
      url
    end

    def store_optimized_image(file, optimized_image, content_type = nil, secure: false)
      optimized_image.url = nil
      path = get_path_for_optimized_image(optimized_image)
      url, optimized_image.etag =
        store_file(file, path, content_type: content_type, private_acl: secure)
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
    #   - existing_external_upload_key
    def store_file(file, path, opts = {})
      path = path.dup

      filename = opts[:filename].presence || File.basename(path)
      # cache file locally when needed
      cache_file(file, File.basename(path)) if opts[:cache_locally]
      options = {
        acl: SiteSetting.s3_use_acls ? (opts[:private_acl] ? "private" : "public-read") : nil,
        cache_control: "max-age=31556952, public, immutable",
        content_type:
          opts[:content_type].presence || MiniMime.lookup_by_filename(filename)&.content_type,
      }

      # Only add a "content disposition: attachment" header for svgs
      # see https://github.com/discourse/discourse/commit/31e31ef44973dc4daaee2f010d71588ea5873b53.
      # Adding this header for all files would break the ability to view attachments in the browser
      if FileHelper.is_svg?(filename)
        options[:content_disposition] = ActionDispatch::Http::ContentDisposition.format(
          disposition: "attachment",
          filename: filename,
        )
      end

      path.prepend(File.join(upload_path, "/")) if Rails.configuration.multisite

      # if this fails, it will throw an exception
      if opts[:move_existing] && opts[:existing_external_upload_key]
        original_path = opts[:existing_external_upload_key]
        options[:apply_metadata_to_destination] = true
        path, etag = s3_helper.copy(original_path, path, options: options)
        delete_file(original_path)
      else
        path, etag = s3_helper.upload(file, path, options)
      end

      # return the upload url and etag
      [File.join(absolute_base_url, path), etag]
    end

    def delete_file(path)
      # delete the object outright without moving to tombstone,
      # not recommended for most use cases
      s3_helper.delete_object(path)
    end

    def remove_file(url, path)
      return unless has_been_uploaded?(url)
      # copy the removed file to tombstone
      s3_helper.remove(path, true)
    end

    def copy_file(url, source, destination)
      return unless has_been_uploaded?(url)
      s3_helper.copy(source, destination)
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
      if SiteSetting.Upload.s3_cdn_url.present?
        SiteSetting.Upload.s3_cdn_url
      else
        "https:#{absolute_base_url}"
      end
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
      force_download: false
    )
      key = path.sub(absolute_base_url + "/", "")
      presigned_get_url(key, expires_in: expires_in, force_download: force_download)
    end

    def signed_request_for_temporary_upload(
      file_name,
      expires_in: S3Helper::UPLOAD_URL_EXPIRES_AFTER_SECONDS,
      metadata: {}
    )
      key = temporary_upload_path(file_name)
      s3_helper.presigned_request(
        key,
        method: :put_object,
        expires_in: expires_in,
        opts: {
          metadata: metadata,
          acl: SiteSetting.s3_use_acls ? "private" : nil,
        },
      )
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
      s3_helper.copy(source, destination)
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
    end

    def update_upload_ACL(upload, optimized_images_preloaded: false)
      key = get_upload_key(upload)
      update_ACL(key, upload.secure?)

      # If we do find_each when the images have already been preloaded with
      # includes(:optimized_images), then the optimized_images are fetched
      # from the database again, negating the preloading if this operation
      # is done on a large amount of uploads at once (see Jobs::SyncAclsForUploads)
      if optimized_images_preloaded
        upload.optimized_images.each do |optimized_image|
          update_optimized_image_acl(optimized_image, secure: upload.secure)
        end
      else
        upload.optimized_images.find_each do |optimized_image|
          update_optimized_image_acl(optimized_image, secure: upload.secure)
        end
      end

      true
    end

    def update_optimized_image_acl(optimized_image, secure: false)
      optimized_image_key = get_path_for_optimized_image(optimized_image)
      optimized_image_key.prepend(File.join(upload_path, "/")) if Rails.configuration.multisite
      update_ACL(optimized_image_key, secure)
    end

    def download_file(upload, destination_path)
      s3_helper.download_file(get_upload_key(upload), destination_path)
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
      key = temporary_upload_path(file_name)
      s3_helper.create_multipart(key, content_type, metadata: metadata)
    end

    private

    def presigned_get_url(
      url,
      force_download: false,
      filename: false,
      expires_in: SiteSetting.s3_presigned_get_url_expires_after_seconds
    )
      opts = { expires_in: expires_in }

      if force_download && filename
        opts[:response_content_disposition] = ActionDispatch::Http::ContentDisposition.format(
          disposition: "attachment",
          filename: filename,
        )
      end

      obj = object_from_path(url)
      obj.presigned_url(:get, opts)
    end

    def get_upload_key(upload)
      if Rails.configuration.multisite
        File.join(upload_path, "/", get_path_for_upload(upload))
      else
        get_path_for_upload(upload)
      end
    end

    def update_ACL(key, secure)
      begin
        object_from_path(key).acl.put(
          acl: SiteSetting.s3_use_acls ? (secure ? "private" : "public-read") : nil,
        )
      rescue Aws::S3::Errors::NoSuchKey
        Rails.logger.warn("Could not update ACL on upload with key: '#{key}'. Upload is missing.")
      end
    end

    def list_missing(model, prefix)
      connection = ActiveRecord::Base.connection.raw_connection
      connection.exec("CREATE TEMP TABLE verified_ids(val integer PRIMARY KEY)")
      marker = nil
      files = s3_helper.list(prefix, marker)

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
        files = s3_helper.list(prefix, marker)
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
