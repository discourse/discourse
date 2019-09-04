# frozen_string_literal: true

require "uri"
require "mini_mime"
require_dependency "file_store/base_store"
require_dependency "s3_helper"
require_dependency "file_helper"

module FileStore

  class S3Store < BaseStore
    TOMBSTONE_PREFIX ||= "tombstone/"

    attr_reader :s3_helper

    def initialize(s3_helper = nil)
      @s3_helper = s3_helper || S3Helper.new(s3_bucket,
        Rails.configuration.multisite ? multisite_tombstone_prefix : TOMBSTONE_PREFIX
      )
    end

    def store_upload(file, upload, content_type = nil)
      path = get_path_for_upload(upload)
      url, upload.etag = store_file(file, path, filename: upload.original_filename, content_type: content_type, cache_locally: true, private: upload.private?)
      url
    end

    def store_optimized_image(file, optimized_image, content_type = nil)
      path = get_path_for_optimized_image(optimized_image)
      url, optimized_image.etag = store_file(file, path, content_type: content_type)
      url
    end

    # options
    #   - filename
    #   - content_type
    #   - cache_locally
    def store_file(file, path, opts = {})
      path = path.dup

      filename = opts[:filename].presence || File.basename(path)
      # cache file locally when needed
      cache_file(file, File.basename(path)) if opts[:cache_locally]
      options = {
        acl: opts[:private] ? "private" : "public-read",
        cache_control: 'max-age=31556952, public, immutable',
        content_type: opts[:content_type].presence || MiniMime.lookup_by_filename(filename)&.content_type
      }
      # add a "content disposition" header for "attachments"
      options[:content_disposition] = "attachment; filename=\"#{filename}\"" unless FileHelper.is_supported_image?(filename)

      path.prepend(File.join(upload_path, "/")) if Rails.configuration.multisite

      # if this fails, it will throw an exception
      path, etag = @s3_helper.upload(file, path, options)

      # return the upload url and etag
      return File.join(absolute_base_url, path), etag
    end

    def remove_file(url, path)
      return unless has_been_uploaded?(url)
      # copy the removed file to tombstone
      @s3_helper.remove(path, true)
    end

    def copy_file(url, source, destination)
      return unless has_been_uploaded?(url)
      @s3_helper.copy(source, destination)
    end

    def has_been_uploaded?(url)
      return false if url.blank?

      base_hostname = URI.parse(absolute_base_url).hostname
      return true if url[base_hostname]

      return false if SiteSetting.Upload.s3_cdn_url.blank?
      cdn_hostname = URI.parse(SiteSetting.Upload.s3_cdn_url || "").hostname
      cdn_hostname.presence && url[cdn_hostname]
    end

    def s3_bucket_name
      @s3_helper.s3_bucket_name
    end

    def absolute_base_url
      @absolute_base_url ||= SiteSetting.Upload.absolute_base_url
    end

    def external?
      true
    end

    def purge_tombstone(grace_period)
      @s3_helper.update_tombstone_lifecycle(grace_period)
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
      FileStore::LocalStore.new.path_for(upload) if url && url[/^\/[^\/]/]
    end

    def url_for(upload, force_download: false)
      if upload.private? || force_download
        opts = { expires_in: S3Helper::DOWNLOAD_URL_EXPIRES_AFTER_SECONDS }

        if force_download
          opts[:response_content_disposition] = ActionDispatch::Http::ContentDisposition.format(
            disposition: "attachment", filename: upload.original_filename
          )
        end

        obj = @s3_helper.object(get_upload_key(upload))
        url = obj.presigned_url(:get, opts)
      else
        url = upload.url
      end

      url
    end

    def cdn_url(url)
      return url if SiteSetting.Upload.s3_cdn_url.blank?
      schema = url[/^(https?:)?\/\//, 1]
      folder = @s3_helper.s3_bucket_folder_path.nil? ? "" : "#{@s3_helper.s3_bucket_folder_path}/"
      url.sub(File.join("#{schema}#{absolute_base_url}", folder), File.join(SiteSetting.Upload.s3_cdn_url, "/"))
    end

    def cache_avatar(avatar, user_id)
      source = avatar.url.sub(absolute_base_url + "/", "")
      destination = avatar_template(avatar, user_id).sub(absolute_base_url + "/", "")
      @s3_helper.copy(source, destination)
    end

    def avatar_template(avatar, user_id)
      UserAvatar.external_avatar_url(user_id, avatar.upload_id, avatar.width)
    end

    def s3_bucket
      raise Discourse::SiteSettingMissing.new("s3_upload_bucket") if SiteSetting.Upload.s3_upload_bucket.blank?
      SiteSetting.Upload.s3_upload_bucket.downcase
    end

    def list_missing_uploads(skip_optimized: false)
      if SiteSetting.enable_s3_inventory
        require 's3_inventory'
        S3Inventory.new(s3_helper, :upload).backfill_etags_and_list_missing
        S3Inventory.new(s3_helper, :optimized).backfill_etags_and_list_missing unless skip_optimized
      else
        list_missing(Upload.by_users, "original/")
        list_missing(OptimizedImage, "optimized/") unless skip_optimized
      end
    end

    def update_upload_ACL(upload)
      private_uploads = SiteSetting.prevent_anons_from_downloading_files
      key = get_upload_key(upload)

      begin
        @s3_helper.object(key).acl.put(acl: private_uploads ? "private" : "public-read")
      rescue Aws::S3::Errors::NoSuchKey
        Rails.logger.warn("Could not update ACL on upload with key: '#{key}'. Upload is missing.")
      end
    end

    def download_file(upload, destination_path)
      @s3_helper.download_file(get_upload_key(upload), destination_path)
    end

    private

    def get_upload_key(upload)
      if Rails.configuration.multisite
        File.join(upload_path, "/", get_path_for_upload(upload))
      else
        get_path_for_upload(upload)
      end
    end

    def list_missing(model, prefix)
      connection = ActiveRecord::Base.connection.raw_connection
      connection.exec('CREATE TEMP TABLE verified_ids(val integer PRIMARY KEY)')
      marker = nil
      files = @s3_helper.list(prefix, marker)

      while files.count > 0 do
        verified_ids = []

        files.each do |f|
          id = model.where("url LIKE '%#{f.key}' AND etag = '#{f.etag}'").pluck(:id).first
          verified_ids << id if id.present?
          marker = f.key
        end

        verified_id_clause = verified_ids.map { |id| "('#{PG::Connection.escape_string(id.to_s)}')" }.join(",")
        connection.exec("INSERT INTO verified_ids VALUES #{verified_id_clause}")
        files = @s3_helper.list(prefix, marker)
      end

      missing_uploads = model.joins('LEFT JOIN verified_ids ON verified_ids.val = id').where("verified_ids.val IS NULL")
      missing_count = missing_uploads.count

      if missing_count > 0
        missing_uploads.find_each do |upload|
          puts upload.url
        end

        puts "#{missing_count} of #{model.count} #{model.name.underscore.pluralize} are missing"
      end
    ensure
      connection.exec('DROP TABLE verified_ids') unless connection.nil?
    end
  end
end
