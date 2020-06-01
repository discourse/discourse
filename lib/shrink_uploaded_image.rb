# frozen_string_literal: true

class ShrinkUploadedImage
  attr_reader :upload, :path

  def initialize(upload:, path:, max_pixels:, verbose: false, interactive: false)
    @upload = upload
    @path = path
    @max_pixels = max_pixels
    @verbose = verbose
    @interactive = interactive
  end

  def perform
    OptimizedImage.downsize(path, path, "#{@max_pixels}@", filename: upload.original_filename)
    sha1 = Upload.generate_digest(path)

    if sha1 == upload.sha1
      log "No sha1 change"
      return false
    end

    w, h = FastImage.size(path, timeout: 15, raise_on_failure: true)

    if !w || !h
      log "Invalid image dimensions after resizing"
      return false
    end

    # Neither #dup or #clone provide a complete copy
    original_upload = Upload.find(upload.id)
    ww, hh = ImageSizer.resize(w, h)

    # A different upload record that matches the sha1 of the downsized image
    existing_upload = Upload.find_by(sha1: sha1)
    @upload = existing_upload if existing_upload

    upload.attributes = {
      sha1: sha1,
      width: w,
      height: h,
      thumbnail_width: ww,
      thumbnail_height: hh,
      filesize: File.size(path)
    }

    if upload.filesize > upload.filesize_was
      log "No filesize reduction"
      return false
    end

    unless existing_upload
      url = Discourse.store.store_upload(File.new(path), upload)

      unless url
        log "Couldn't store the upload"
        return false
      end

      upload.url = url
    end

    log "base62: #{original_upload.base62_sha1} -> #{Upload.base62_sha1(sha1)}"
    log "sha: #{original_upload.sha1} -> #{sha1}"
    log "(an exisiting upload)" if existing_upload

    success = true
    posts = Post.unscoped.joins(:post_uploads).where(post_uploads: { upload_id: original_upload.id }).uniq.sort_by(&:created_at)

    posts.each do |post|
      transform_post(post, original_upload, upload)

      if post.custom_fields[Post::DOWNLOADED_IMAGES].present?
        downloaded_images = JSON.parse(post.custom_fields[Post::DOWNLOADED_IMAGES])
      end

      if post.raw_changed?
        log "Updating post"
      elsif downloaded_images&.has_value?(original_upload.id)
        log "A hotlinked, unreferenced image"
      elsif post.raw.include?(upload.short_url)
        log "Already processed"
      elsif post.trashed?
        log "A deleted post"
      elsif !post.topic || post.topic.trashed?
        log "A deleted topic"
      elsif post.cooked.include?(original_upload.sha1)
        if post.raw.include?("#{Discourse.base_url.sub(/^https?:\/\//i, "")}/t/")
          log "Updating a topic onebox"
        else
          log "Updating an external onebox"
        end
      else
        log "Could not find the upload URL"
        success = false
      end

      log "#{Discourse.base_url}/p/#{post.id}"
    end

    if posts.empty?
      log "Upload not used in any posts"

      if User.where(uploaded_avatar_id: original_upload.id).exists?
        log "Used as a User avatar"
      elsif UserAvatar.where(gravatar_upload_id: original_upload.id).exists?
        log "Used as a UserAvatar gravatar"
      elsif UserAvatar.where(custom_upload_id: original_upload.id).exists?
        log "Used as a UserAvatar custom upload"
      elsif UserProfile.where(profile_background_upload_id: original_upload.id).exists?
        log "Used as a UserProfile profile background"
      elsif UserProfile.where(card_background_upload_id: original_upload.id).exists?
        log "Used as a UserProfile card background"
      elsif Category.where(uploaded_logo_id: original_upload.id).exists?
        log "Used as a Category logo"
      elsif Category.where(uploaded_background_id: original_upload.id).exists?
        log "Used as a Category background"
      elsif CustomEmoji.where(upload_id: original_upload.id).exists?
        log "Used as a CustomEmoji"
      elsif ThemeField.where(upload_id: original_upload.id).exists?
        log "Used as a ThemeField"
      else
        success = false
      end
    end

    unless success
      if @interactive
        print "Press any key to continue with the upload"
        STDIN.beep
        STDIN.getch
        puts " k"
      else
        if !existing_upload && !Upload.where(url: upload.url).exists?
          # We're bailing, so clean up the just uploaded file
          Discourse.store.remove_upload(upload)
        end

        log "⏩ Skipping"
        return false
      end
    end

    unless upload.save
      if !existing_upload && !Upload.where(url: upload.url).exists?
        # We're bailing, so clean up the just uploaded file
        Discourse.store.remove_upload(upload)
      end

      log "⏩ Skipping an invalid upload"
      return false
    end

    if existing_upload
      begin
        PostUpload.where(upload_id: original_upload.id).update_all(upload_id: upload.id)
      rescue ActiveRecord::RecordNotUnique, PG::UniqueViolation
      end

      User.where(uploaded_avatar_id: original_upload.id).update_all(uploaded_avatar_id: upload.id)
      UserAvatar.where(gravatar_upload_id: original_upload.id).update_all(gravatar_upload_id: upload.id)
      UserAvatar.where(custom_upload_id: original_upload.id).update_all(custom_upload_id: upload.id)
      UserProfile.where(profile_background_upload_id: original_upload.id).update_all(profile_background_upload_id: upload.id)
      UserProfile.where(card_background_upload_id: original_upload.id).update_all(card_background_upload_id: upload.id)
      Category.where(uploaded_logo_id: original_upload.id).update_all(uploaded_logo_id: upload.id)
      Category.where(uploaded_background_id: original_upload.id).update_all(uploaded_background_id: upload.id)
      CustomEmoji.where(upload_id: original_upload.id).update_all(upload_id: upload.id)
      ThemeField.where(upload_id: original_upload.id).update_all(upload_id: upload.id)
    else
      upload.optimized_images.each(&:destroy!)
    end

    posts.each do |post|
      DistributedMutex.synchronize("process_post_#{post.id}") do
        current_post = Post.unscoped.find(post.id)

        # If the post became outdated, reapply changes
        if current_post.updated_at != post.updated_at
          transform_post(current_post, original_upload, upload)
          post = current_post
        end

        if post.raw_changed?
          post.update_columns(
            raw: post.raw,
            updated_at: Time.zone.now
          )
        end

        if existing_upload && post.custom_fields[Post::DOWNLOADED_IMAGES].present?
          downloaded_images = JSON.parse(post.custom_fields[Post::DOWNLOADED_IMAGES])

          downloaded_images.transform_values! do |upload_id|
            upload_id == original_upload.id ? upload.id : upload_id
          end

          post.custom_fields[Post::DOWNLOADED_IMAGES] = downloaded_images.to_json if downloaded_images.present?
          post.save_custom_fields
        end

        post.rebake!
      end
    end

    if existing_upload
      original_upload.reload.destroy!
    else
      Discourse.store.remove_upload(original_upload)
    end

    true
  end

  private

  def transform_post(post, upload_before, upload_after)
    post.raw.gsub!(/upload:\/\/#{upload_before.base62_sha1}(\.#{upload_before.extension})?/i, upload_after.short_url)
    post.raw.gsub!(Discourse.store.cdn_url(upload_before.url), Discourse.store.cdn_url(upload_after.url))
    post.raw.gsub!("#{Discourse.base_url}#{upload_before.short_path}", "#{Discourse.base_url}#{upload_after.short_path}")

    if SiteSetting.enable_s3_uploads
      post.raw.gsub!(Discourse.store.url_for(upload_before), Discourse.store.url_for(upload_after))

      path = SiteSetting.Upload.s3_upload_bucket.split("/", 2)[1]
      post.raw.gsub!(/<img src=\"https:\/\/.+?\/#{path}\/uploads\/default\/optimized\/.+?\/#{upload_before.sha1}_\d_(?<width>\d+)x(?<height>\d+).*?\" alt=\"(?<alt>.*?)\"\/?>/i) do
        "![#{$~[:alt]}|#{$~[:width]}x#{$~[:height]}](#{upload_after.short_url})"
      end
    end

    post.raw.gsub!(/!\[(.*?)\]\(\/uploads\/.+?\/#{upload_before.sha1}(\.#{upload_before.extension})?\)/i, "![\\1](#{upload_after.short_url})")
  end

  def log(*args)
    puts(*args) if @verbose
  end
end
