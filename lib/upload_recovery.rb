# frozen_string_literal: true

class UploadRecovery
  def initialize(dry_run: false, stop_on_error: false)
    @dry_run = dry_run
    @stop_on_error = stop_on_error
  end

  def recover(posts = Post)
    posts.have_uploads.find_each { |post| recover_post post }
  end

  def recover_post(post)
    begin
      analyzer = PostAnalyzer.new(post.raw, post.topic_id)

      analyzer.cooked_stripped.css("img", "a").each do |media|
        if media.name == "img" && orig_src = media["data-orig-src"]
          if dom_class = media["class"]
            if (Post.white_listed_image_classes & dom_class.split).count > 0
              next
            end
          end

          if @dry_run
            puts "#{post.full_url} #{orig_src}"
          else
            recover_post_upload(post, Upload.sha1_from_short_url(orig_src))
          end
        elsif url = (media["href"] || media["src"])
          data = Upload.extract_url(url)
          next unless data

          sha1 = data[2]

          unless upload = Upload.get_from_url(url)
            if @dry_run
              puts "#{post.full_url} #{url}"
            else
              recover_post_upload(post, sha1)
            end
          end
        end
      end
    rescue => e
      raise e if @stop_on_error
      puts "#{post.full_url} #{e.class}: #{e.message}"
    end
  end

  private

  def recover_post_upload(post, sha1)
    return unless valid_sha1?(sha1)

    attributes = {
      post: post,
      sha1: sha1
    }

    if Discourse.store.external?
      recover_post_upload_from_s3(attributes)
    else
      recover_post_upload_from_local(attributes)
    end
  end

  def ensure_upload!(post:, sha1:, upload:)
    return if !upload.persisted?

    if upload.sha1 != sha1
      STDERR.puts "Warning #{post.url} had an incorrect #{sha1} should be #{upload.sha1} storing in custom field 'rake uploads:fix_relative_upload_links' can fix this"

      sha_map = post.custom_fields["UPLOAD_SHA1_MAP"] || "{}"
      sha_map = JSON.parse(sha_map)
      sha_map[sha1] = upload.sha1

      post.custom_fields["UPLOAD_SHA1_MAP"] = sha_map.to_json
      post.save_custom_fields
    end

    post.rebake!
  end

  def recover_post_upload_from_local(post:, sha1:)
    recover_from_local(sha1: sha1, user_id: post.user_id) do |upload|
      ensure_upload!(post: post, sha1: sha1, upload: upload)
    end
  end

  def recover_post_upload_from_s3(post:, sha1:)
    recover_from_s3(sha1: sha1, user_id: post.user_id) do |upload|
      ensure_upload!(post: post, sha1: sha1, upload: upload)
    end
  end

  def recover_from_local(sha1:, user_id:)
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
          tmp = Tempfile.new
          tmp.write(File.read(path))
          tmp.rewind

          upload = create_upload(tmp, File.basename(path), user_id)
          yield upload if block_given?
        ensure
          tmp&.close
        end
      end
    end
  end

  def recover_from_s3(sha1:, user_id:)
    @object_keys ||= begin
      s3_helper = Discourse.store.s3_helper

      if Rails.configuration.multisite
        current_db = RailsMultisite::ConnectionManagement.current_db
        s3_helper.list("uploads/#{current_db}/original").map(&:key).concat(
          s3_helper.list("uploads/#{FileStore::S3Store::TOMBSTONE_PREFIX}#{current_db}/original").map(&:key)
        )
      else
        s3_helper.list("original").map(&:key).concat(
          s3_helper.list("#{FileStore::S3Store::TOMBSTONE_PREFIX}original").map(&:key)
        )
      end
    end

    @object_keys.each do |key|
      if key =~ /#{sha1}/
        tombstone_prefix = FileStore::S3Store::TOMBSTONE_PREFIX

        if key.include?(tombstone_prefix)
          old_key = key
          key = key.sub(tombstone_prefix, "")

          Discourse.store.s3_helper.copy(
            old_key,
            key,
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

          if tmp
            upload = create_upload(tmp, File.basename(key), user_id)
            yield upload if block_given?
          end
        ensure
          tmp&.close
        end
      end
    end
  end

  def create_upload(file, filename, user_id)
    UploadCreator.new(file, filename).create_for(user_id)
  end

  def valid_sha1?(sha1)
    sha1.present? && sha1.length == Upload::SHA1_LENGTH
  end
end
