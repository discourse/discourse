require 'file_store/base_store'

module FileStore

  class LocalStore < BaseStore

    def store_upload(file, upload)
      path = get_path_for_upload(file, upload)
      store_file(file, path)
    end

    def store_optimized_image(file, optimized_image)
      path = get_path_for_optimized_image(file, optimized_image)
      store_file(file, path)
    end

    def store_avatar(file, avatar, size)
      path = get_path_for_avatar(file, avatar, size)
      store_file(file, path)
    end

    def remove_upload(upload)
      remove_file(upload.url)
    end

    def remove_optimized_image(optimized_image)
      remove_file(optimized_image.url)
    end

    def has_been_uploaded?(url)
      is_relative?(url) || is_local?(url)
    end

    def absolute_base_url
      "#{Discourse.base_url_no_prefix}#{relative_base_url}"
    end

    def relative_base_url
      "/uploads/#{RailsMultisite::ConnectionManagement.current_db}"
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

    def absolute_avatar_template(avatar)
      avatar_template(avatar, absolute_base_url)
    end

    private

    def get_path_for_upload(file, upload)
      unique_sha1 = Digest::SHA1.hexdigest("#{Time.now.to_s}#{file.original_filename}")[0..15]
      extension = File.extname(file.original_filename)
      clean_name = "#{unique_sha1}#{extension}"
      # path
      "#{relative_base_url}/#{upload.id}/#{clean_name}"
    end

    def get_path_for_optimized_image(file, optimized_image)
      # 1234567890ABCDEF_100x200.jpg
      filename = [
        optimized_image.sha1[6..15],
        "_#{optimized_image.width}x#{optimized_image.height}",
        optimized_image.extension,
      ].join
      # path
      "#{relative_base_url}/_optimized/#{optimized_image.sha1[0..2]}/#{optimized_image.sha1[3..5]}/#{filename}"
    end

    def get_path_for_avatar(file, avatar, size)
      relative_avatar_template(avatar).gsub("{size}", size.to_s)
    end

    def relative_avatar_template(avatar)
      avatar_template(avatar, relative_base_url)
    end

    def avatar_template(avatar, base_url)
      File.join(
        base_url,
        "avatars",
        avatar.sha1[0..2],
        avatar.sha1[3..5],
        avatar.sha1[6..15],
        "{size}#{avatar.extension}"
      )
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
      # not using cause mv, cause permissions are no good on move
      File.open(path, "wb") do |f|
        f.write(file.read)
      end
    end

    def remove_file(url)
      File.delete("#{public_dir}#{url}") if is_relative?(url)
    rescue Errno::ENOENT
      # don't care if the file isn't there
    end

    def is_relative?(url)
      url.start_with?(relative_base_url)
    end

    def is_local?(url)
      absolute_url = url.start_with?("//") ? (SiteSetting.use_ssl? ? "https:" : "http:") + url : url
      absolute_url.start_with?(absolute_base_url) || absolute_url.start_with?(absolute_base_cdn_url)
    end

    def absolute_base_cdn_url
      "#{Discourse.asset_host}#{relative_base_url}"
    end

    def public_dir
      "#{Rails.root}/public"
    end

  end

end
