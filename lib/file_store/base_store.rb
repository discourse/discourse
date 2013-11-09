module FileStore

  class BaseStore

    def store_upload(file, upload)
    end

    def store_optimized_image(file, optimized_image)
    end

    def store_avatar(file, avatar, size)
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

    def external?
    end

    def internal?
    end

    def path_for(upload)
    end

    def download(upload)
    end

    def absolute_avatar_template(avatar)
    end

  end

end
