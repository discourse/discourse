# frozen_string_literal: true

module FileStore

  class BaseStore
    UPLOAD_PATH_REGEX ||= %r|/(original/\d+X/.*)|
    OPTIMIZED_IMAGE_PATH_REGEX ||= %r|/(optimized/\d+X/.*)|
    TEMPORARY_UPLOAD_PREFIX ||= "temp/"

    def store_upload(file, upload, content_type = nil)
      upload.url = nil
      path = get_path_for_upload(upload)
      store_file(file, path)
    end

    def store_optimized_image(file, optimized_image, content_type = nil, secure: false)
      optimized_image.url = nil
      path = get_path_for_optimized_image(optimized_image)
      store_file(file, path)
    end

    def store_file(file, path, opts = {})
      not_implemented
    end

    def remove_upload(upload)
      remove_file(upload.url, get_path_for_upload(upload))
    end

    def remove_optimized_image(optimized_image)
      remove_file(optimized_image.url, get_path_for_optimized_image(optimized_image))
    end

    def remove_file(url, path)
      not_implemented
    end

    def upload_path
      path = File.join("uploads", RailsMultisite::ConnectionManagement.current_db)
      return path if !Rails.env.test?
      File.join(path, "test_#{ENV['TEST_ENV_NUMBER'].presence || '0'}")
    end

    def self.temporary_upload_path(file_name, folder_prefix: "")
      # We don't want to use the original file name as it can contain special
      # characters, which can interfere with external providers operations and
      # introduce other unexpected behaviour.
      file_name_random = "#{SecureRandom.hex}#{File.extname(file_name)}"
      File.join(
        TEMPORARY_UPLOAD_PREFIX,
        folder_prefix,
        SecureRandom.hex,
        file_name_random
      )
    end

    def has_been_uploaded?(url)
      not_implemented
    end

    def download_url(upload)
      not_implemented
    end

    def cdn_url(url)
      not_implemented
    end

    def absolute_base_url
      not_implemented
    end

    def relative_base_url
      not_implemented
    end

    def s3_upload_host
      not_implemented
    end

    def external?
      not_implemented
    end

    def internal?
      !external?
    end

    def path_for(upload)
      not_implemented
    end

    def list_missing_uploads(skip_optimized: false)
      not_implemented
    end

    def download(object, max_file_size_kb: nil)
      DistributedMutex.synchronize("download_#{object.sha1}", validity: 3.minutes) do
        extension = File.extname(object.respond_to?(:original_filename) ? object.original_filename : object.url)
        filename = "#{object.sha1}#{extension}"
        file = get_from_cache(filename)

        if !file
          max_file_size_kb ||= [SiteSetting.max_image_size_kb, SiteSetting.max_attachment_size_kb].max.kilobytes

          secure = object.respond_to?(:secure) ? object.secure? : object.upload.secure?
          url = secure ?
            Discourse.store.signed_url_for_path(object.url) :
            Discourse.store.cdn_url(object.url)

          url = SiteSetting.scheme + ":" + url if url =~ /^\/\//
          file = FileHelper.download(
            url,
            max_file_size: max_file_size_kb,
            tmp_file_name: "discourse-download",
            follow_redirect: true
          )

          cache_file(file, filename)
          file = get_from_cache(filename)
        end

        file
      end
    end

    def purge_tombstone(grace_period)
    end

    def get_path_for(type, id, sha, extension)
      depth = get_depth_for(id)
      tree = File.join(*sha[0, depth].chars, "")
      "#{type}/#{depth + 1}X/#{tree}#{sha}#{extension}"
    end

    def get_path_for_upload(upload)
      # try to extract the path from the URL instead of calculating it,
      # because the calculated path might differ from the actual path
      if upload.url.present? && (path = upload.url[UPLOAD_PATH_REGEX, 1])
        return prefix_path(path)
      end

      extension =
        if upload.extension
          ".#{upload.extension}"
        else
          # Maintain backward compatibility before Jobs::MigrateUploadExtensions runs
          File.extname(upload.original_filename)
        end

      get_path_for("original", upload.id, upload.sha1, extension)
    end

    def get_path_for_optimized_image(optimized_image)
      # try to extract the path from the URL instead of calculating it,
      # because the calculated path might differ from the actual path
      if optimized_image.url.present? && (path = optimized_image.url[OPTIMIZED_IMAGE_PATH_REGEX, 1])
        return prefix_path(path)
      end

      upload = optimized_image.upload
      version = optimized_image.version || 1
      extension = "_#{version}_#{optimized_image.width}x#{optimized_image.height}#{optimized_image.extension}"
      get_path_for("optimized", upload.id, upload.sha1, extension)
    end

    CACHE_DIR ||= "#{Rails.root}/tmp/download_cache/"
    CACHE_MAXIMUM_SIZE ||= 500

    def get_cache_path_for(filename)
      "#{CACHE_DIR}#{filename}"
    end

    def get_from_cache(filename)
      path = get_cache_path_for(filename)
      File.open(path) if File.exist?(path)
    end

    def cache_file(file, filename)
      path = get_cache_path_for(filename)
      dir = File.dirname(path)
      FileUtils.mkdir_p(dir) unless Dir.exist?(dir)
      FileUtils.cp(file.path, path)

      # Remove all but CACHE_MAXIMUM_SIZE most recent files
      files = Dir.glob("#{CACHE_DIR}*")
      files.sort_by! do |f|
        begin
          File.mtime(f)
        rescue Errno::ENOENT
          Time.new(0)
        end
      end
      files.pop(CACHE_MAXIMUM_SIZE)

      FileUtils.rm(files, force: true)
    end

    private

    def not_implemented
      raise "Not implemented."
    end

    def get_depth_for(id)
      depths = [0]
      depths << Math.log(id / 1_000.0, 16).ceil if id.positive?
      depths.max
    end

    def prefix_path(path)
      path
    end
  end

end
