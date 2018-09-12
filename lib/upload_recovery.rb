class UploadRecovery
  def recover
    Post.where("raw LIKE '%upload:\/\/%'").find_each do |post|
      analyzer = PostAnalyzer.new(post.raw, post.topic_id)
      cooked_stripped = analyzer.send(:cooked_stripped)

      cooked_stripped.css("img").each do |img|
        if dom_class = img["class"]
          if (Post.white_listed_image_classes & dom_class.split).count > 0
            next
          end
        end

        if img["data-orig-src"]
          recover_post_upload(post, img["data-orig-src"])
        end
      end
    end
  end

  private

  def recover_post_upload(post, short_url)
    attributes = {
      post: post,
      sha1: Upload.sha1_from_short_url(short_url)
    }

    if Discourse.store.external?
      recover_from_s3(attributes)
    else
      recover_from_local(attributes)
    end
  end

  def recover_from_local(post:, sha1:)
    public_path = Rails.root.join("public")

    @paths ||= begin
      Dir.glob(File.join(
        public_path,
        'uploads',
        'tombstone',
        RailsMultisite::ConnectionManagement.current_db,
        'original',
        '**',
        '*.*'
      )).concat(Dir.glob(File.join(
        public_path,
        'uploads',
        RailsMultisite::ConnectionManagement.current_db,
        'original',
        '**',
        '*.*'
      )))
    end

    @paths.each do |path|
      if path =~ /#{sha1}/
        begin
          file = File.open(path, "r")
          create_upload(file, File.basename(path), post)
        ensure
          file&.close
        end
      end
    end
  end

  def recover_from_s3(post:, sha1:)
    @object_keys ||= begin
      s3_helper = Discourse.store.s3_helper

      s3_helper.list("original").map(&:key).concat(
        s3_helper.list("#{FileStore::S3Store::TOMBSTONE_PREFIX}original").map(&:key)
      )
    end

    @object_keys.each do |key|
      if key =~ /#{sha1}/
        tombstone_prefix = FileStore::S3Store::TOMBSTONE_PREFIX

        if key.starts_with?(tombstone_prefix)
          Discourse.store.s3_helper.copy(
            key,
            key.sub(tombstone_prefix, ""),
            options: { acl: "public-read" }
          )
        end

        url = "https:#{SiteSetting.Upload.absolute_base_url}/#{key}"

        begin
          tmp = FileHelper.download(
            url,
            max_file_size: SiteSetting.max_image_size_kb.kilobytes,
            tmp_file_name: "recover_from_s3"
          )

          create_upload(tmp, File.basename(key), post) if tmp
        ensure
          tmp&.close
        end
      end
    end
  end

  def create_upload(file, filename, post)
    upload = UploadCreator.new(tmp, filename).create_for(post.user_id)
    post.rebake! if upload.persisted?
  end
end
