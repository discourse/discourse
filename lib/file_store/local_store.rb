require_dependency 'file_store/base_store'

module FileStore

  class LocalStore < BaseStore

    def store_file(file, path)
      copy_file(file, "#{public_dir}#{path}")
      "#{Discourse.base_uri}#{path}"
    end

    def remove_file(url)
      return unless is_relative?(url)
      path = public_dir + url
      return if !File.exists?(path)
      tombstone = public_dir + url.sub("/uploads/", "/uploads/tombstone/")
      FileUtils.mkdir_p(tombstone_dir)
      FileUtils.move(path, tombstone, force: true)
    end

    def has_been_uploaded?(url)
      return false if url.blank?
      return true if is_relative?(url)
      return true if is_local?(url)
      false
    end

    def absolute_base_url
      "#{Discourse.base_url_no_prefix}#{relative_base_url}"
    end

    def absolute_base_cdn_url
      "#{Discourse.asset_host}#{relative_base_url}"
    end

    def upload_path
      "/uploads/#{RailsMultisite::ConnectionManagement.current_db}"
    end

    def relative_base_url
      "#{Discourse.base_uri}#{upload_path}"
    end

    def external?
      false
    end

    def download_url(upload)
      return unless upload
      "#{relative_base_url}/#{upload.sha1}"
    end

    def path_for(upload)
      url = upload.try(:url)
      "#{public_dir}#{upload.url}" if url && url[0] == "/" && url[1] != "/"
    end

    def purge_tombstone(grace_period)
      `find #{tombstone_dir} -mtime +#{grace_period} -type f -delete`
    end

    def get_path_for(type, upload_id, sha, extension)
      "#{upload_path}/#{super(type, upload_id, sha, extension)}"
    end

    def copy_file(file, path)
      FileUtils.mkdir_p(Pathname.new(path).dirname)
      # move the file to the right location
      # not using mv, cause permissions are no good on move
      File.open(path, "wb") { |f| f.write(file.read) }
    end

    def is_relative?(url)
      url.present? && url.start_with?(relative_base_url)
    end

    def is_local?(url)
      return false if url.blank?
      absolute_url = url.start_with?("//") ? SiteSetting.scheme + ":" + url : url
      absolute_url.start_with?(absolute_base_url) || absolute_url.start_with?(absolute_base_cdn_url)
    end

    def public_dir
      "#{Rails.root}/public"
    end

    def tombstone_dir
      public_dir + relative_base_url.sub("/uploads/", "/uploads/tombstone/")
    end

  end

end
