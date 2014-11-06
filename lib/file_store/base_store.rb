module FileStore

  class BaseStore

    def store_upload(file, upload, content_type = nil)
    end

    def store_optimized_image(file, optimized_image)
    end

    def remove_upload(upload)
    end

    def remove_optimized_image(optimized_image)
    end

    def has_been_uploaded?(url)
    end

    def absolute_base_url
    end

    def relative_base_url
    end

    def download_url(upload)
    end

    def external?
    end

    def internal?
    end

    def path_for(upload)
    end

    def download(upload)
    end

    def avatar_template(avatar)
    end

    def purge_tombstone(grace_period)
    end

  end

end
