require_dependency 'file_store/base_store'

module FileStore

  class LocalStore < BaseStore

    def store_file(file, path)
      copy_file(file, "#{public_dir}#{path}")
      "#{Discourse.base_uri}#{path}"
    end

    def remove_file(url, _)
      return unless is_relative?(url)
      source = "#{public_dir}#{url}"
      return unless File.exists?(source)
      destination = "#{public_dir}#{url.sub("/uploads/", "/uploads/tombstone/")}"
      dir = Pathname.new(destination).dirname
      FileUtils.mkdir_p(dir) unless Dir.exists?(dir)
      FileUtils.move(source, destination, force: true)
      FileUtils.touch(destination)
    end

    def has_been_uploaded?(url)
      is_relative?(url) || is_local?(url)
    end

    def absolute_base_url
      "#{Discourse.base_url_no_prefix}#{relative_base_url}"
    end

    def absolute_base_cdn_url
      "#{Discourse.asset_host}#{relative_base_url}"
    end

    def relative_base_url
      File.join(Discourse.base_uri, upload_path)
    end

    def external?
      false
    end

    def download_url(upload)
      return unless upload
      File.join(relative_base_url, upload.sha1)
    end

    def cdn_url(url)
      return url if Discourse.asset_host.blank?
      url.sub(Discourse.base_url_no_prefix, Discourse.asset_host)
    end

    def path_for(upload)
      url = upload.try(:url)
      "#{public_dir}#{upload.url}" if url && url[0] == "/" && url[1] != "/"
    end

    def purge_tombstone(grace_period)
      if Dir.exists?(Discourse.store.tombstone_dir)
        Discourse::Utils.execute_command(
          'find', tombstone_dir, '-mtime', "+#{grace_period}", '-type', 'f', '-delete'
        )
      end
    end

    def get_path_for(type, upload_id, sha, extension)
      File.join("/", upload_path, super(type, upload_id, sha, extension))
    end

    def copy_file(file, path)
      dir = Pathname.new(path).dirname
      FileUtils.mkdir_p(dir) unless Dir.exists?(dir)
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
      File.join(Rails.root, "public")
    end

    def tombstone_dir
      "#{public_dir}#{relative_base_url.sub("/uploads/", "/uploads/tombstone/")}"
    end

    def list_missing_uploads(skip_optimized: false)
      list_missing(Upload)
      list_missing(OptimizedImage) unless skip_optimized
    end

    private

    def list_missing(model)
      count = 0
      model.find_each do |upload|

        # could be a remote image
        next unless upload.url =~ /^\/[^\/]/

        path = "#{public_dir}#{upload.url}"
        bad = true
        begin
          bad = false if File.size(path) != 0
        rescue
          # something is messed up
        end
        if bad
          count += 1
          puts path
        end
      end
      puts "#{count} of #{model.count} #{model.name.underscore.pluralize} are missing" if count > 0
    end

  end
end
