require 'file_store/base_store'

module FileStore

  class LocalStore < BaseStore

    def store_upload(file, upload, content_type = nil)
      path = get_path_for_upload(file, upload)
      store_file(file, path)
    end

    def store_optimized_image(file, optimized_image)
      path = get_path_for_optimized_image(file, optimized_image)
      store_file(file, path)
    end

    def remove_upload(upload)
      remove_file(upload.url)
    end

    def remove_optimized_image(optimized_image)
      remove_file(optimized_image.url)
    end

    def has_been_uploaded?(url)
      url.present? && (is_relative?(url) || is_local?(url))
    end

    def absolute_base_url
      "#{Discourse.base_url_no_prefix}#{relative_base_url}"
    end

    def relative_base_url
      "/uploads/#{RailsMultisite::ConnectionManagement.current_db}"
    end

    def download_url(upload)
      return unless upload
      "#{relative_base_url}/#{upload.sha1}"
    end

    def external?
      !internal?
    end

    def internal?
      true
    end

    def path_for(upload)
      "#{public_dir}#{upload.url}"
    end

    def purge_tombstone(grace_period)
      `find #{tombstone_dir} -mtime +#{grace_period} -type f -delete`
    end

    private

    def get_path_for_upload(file, upload)
      get_path_for("original".freeze, upload.sha1, upload.extension)
    end

    def get_path_for_optimized_image(file, optimized_image)
      extension = "_#{optimized_image.width}x#{optimized_image.height}#{optimized_image.extension}"
      get_path_for("optimized".freeze, optimized_image.sha1, extension)
    end

    def get_path_for(type, sha, extension)
      "#{relative_base_url}/#{type}/#{sha[0]}/#{sha[1]}/#{sha}#{extension}"
    end

    def store_file(file, path)
      # copy the file to the right location
      copy_file(file, "#{public_dir}#{path}")
      # url
      "#{Discourse.base_uri}#{path}"
    end

    def copy_file(file, path)
      FileUtils.mkdir_p(Pathname.new(path).dirname)
      # move the file to the right location
      # not using mv, cause permissions are no good on move
      File.open(path, "wb") { |f| f.write(file.read) }
    end

    def remove_file(url)
      return unless is_relative?(url)
      path = public_dir + url
      tombstone = public_dir + url.gsub("/uploads/", "/tombstone/")
      FileUtils.mkdir_p(Pathname.new(tombstone).dirname)
      FileUtils.move(path, tombstone)
    rescue Errno::ENOENT
      # don't care if the file isn't there
    end

    def is_relative?(url)
      url.present? && url.start_with?(relative_base_url)
    end

    def is_local?(url)
      return false if url.blank?
      absolute_url = url.start_with?("//") ? SiteSetting.scheme + ":" + url : url
      absolute_url.start_with?(absolute_base_url) || absolute_url.start_with?(absolute_base_cdn_url)
    end

    def absolute_base_cdn_url
      "#{Discourse.asset_host}#{relative_base_url}"
    end

    def public_dir
      "#{Rails.root}/public"
    end

    def tombstone_dir
      public_dir + relative_base_url.gsub("/uploads/", "/tombstone/")
    end

  end

end
