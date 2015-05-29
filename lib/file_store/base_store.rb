module FileStore

  class BaseStore

    def store_upload(file, upload, content_type = nil)
      path = get_path_for_upload(upload)
      store_file(file, path)
    end

    def store_optimized_image(file, optimized_image)
      path = get_path_for_optimized_image(optimized_image)
      store_file(file, path)
    end

    def store_file(file, path, opts = {})
    end

    def remove_upload(upload)
      remove_file(upload.url)
    end

    def remove_optimized_image(optimized_image)
      remove_file(optimized_image.url)
    end

    def remove_file(url)
    end

    def has_been_uploaded?(url)
    end

    def download_url(upload)
    end

    def cdn_url(url)
      url
    end

    def absolute_base_url
    end

    def relative_base_url
    end

    def external?
    end

    def internal?
      !external?
    end

    def path_for(upload)
    end

    def download(upload)
    end

    def purge_tombstone(grace_period)
    end

    def get_path_for(type, id, sha, extension)
      depth = [0, Math.log(id / 1_000.0, 16).ceil].max
      tree = File.join(*sha[0, depth].split(""), "")
      "#{type}/#{depth + 1}X/#{tree}#{sha}#{extension}"
    end

    def get_path_for_upload(upload)
      get_path_for("original".freeze, upload.id, upload.sha1, upload.extension)
    end

    def get_path_for_optimized_image(optimized_image)
      upload = optimized_image.upload
      extension = "_#{OptimizedImage::VERSION}_#{optimized_image.width}x#{optimized_image.height}#{optimized_image.extension}"
      get_path_for("optimized".freeze, upload.id, upload.sha1, extension)
    end

  end

end
