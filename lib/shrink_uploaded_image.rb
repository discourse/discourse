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
    # Neither #dup or #clone provide a complete copy
    original_upload = Upload.find_by(id: upload.id)
    unless original_upload
      log "Upload is missing"
      return false
    end

    posts =
      Post
        .unscoped
        .joins(:upload_references)
        .where(upload_references: { upload_id: original_upload.id })
        .uniq
        .sort_by(&:created_at)

    if posts.empty?
      log "Upload not used in any posts"
      return false
    end

    OptimizedImage.downsize(path, path, "#{@max_pixels}@", filename: upload.original_filename)
    sha1 = Upload.generate_digest(path)

    if sha1 == upload.sha1
      log "No sha1 change"
      return false
    end

    begin
      w, h = FastImage.size(path, timeout: 15, raise_on_failure: true)
    rescue FastImage::SizeNotFound
      return false
    end

    if !w || !h
      log "Invalid image dimensions after resizing"
      return false
    end

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
      filesize: File.size(path),
    }

    if upload.filesize >= upload.filesize_was
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
    log "(an existing upload)" if existing_upload

    success = true

    posts.each do |post|
      transform_post(post, original_upload, upload)

      if post.raw_changed?
        log "Updating post"
      elsif post.post_hotlinked_media.exists?(upload_id: original_upload.id)
        log "A hotlinked, unreferenced image"
      elsif post.raw.include?(upload.short_url)
        log "Already processed"
      elsif post.trashed?
        log "A deleted post"
      elsif !post.topic || post.topic.trashed?
        log "A deleted topic"
      elsif post.cooked.include?(original_upload.sha1)
        if post.raw.include?("#{Discourse.base_url.sub(%r{\Ahttps?://}i, "")}/t/")
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
        UploadReference
          .where(target_type: "Post")
          .where(upload_id: original_upload.id)
          .update_all(upload_id: upload.id)
      rescue ActiveRecord::RecordNotUnique, PG::UniqueViolation
      end
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

        post.update_columns(raw: post.raw, updated_at: Time.zone.now) if post.raw_changed?

        if existing_upload
          post
            .post_hotlinked_media
            .where(upload_id: original_upload.id)
            .update_all(upload_id: upload.id)
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
    post.raw.gsub!(
      %r{upload://#{upload_before.base62_sha1}(\.#{upload_before.extension})?}i,
      upload_after.short_url,
    )
    post.raw.gsub!(
      Discourse.store.cdn_url(upload_before.url),
      Discourse.store.cdn_url(upload_after.url),
    )
    post.raw.gsub!(
      "#{Discourse.base_url}#{upload_before.short_path}",
      "#{Discourse.base_url}#{upload_after.short_path}",
    )

    if SiteSetting.enable_s3_uploads
      post.raw.gsub!(Discourse.store.url_for(upload_before), Discourse.store.url_for(upload_after))

      path = SiteSetting.Upload.s3_upload_bucket.split("/", 2)[1]
      post
        .raw
        .gsub!(
          %r{<img src=\"https://.+?/#{path}/uploads/default/optimized/.+?/#{upload_before.sha1}_\d_(?<width>\d+)x(?<height>\d+).*?\" alt=\"(?<alt>.*?)\"/?>}i,
        ) { "![#{$~[:alt]}|#{$~[:width]}x#{$~[:height]}](#{upload_after.short_url})" }
    end

    post.raw.gsub!(
      %r{!\[(.*?)\]\(/uploads/.+?/#{upload_before.sha1}(\.#{upload_before.extension})?\)}i,
      "![\\1](#{upload_after.short_url})",
    )
  end

  def log(*args)
    puts(*args) if @verbose
  end
end
