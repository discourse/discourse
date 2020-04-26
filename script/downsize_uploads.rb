# frozen_string_literal: true

require File.expand_path("../../config/environment", __FILE__)

# Supported ENV arguments:
#
# VERBOSE=1
# Shows debug information.
#
# INTERACTIVE=1
# Shows debug information and pauses for input on issues.
#
# WORKER_ID/WORKER_COUNT
# When running the script on a single forum in multiple terminals.
# For example, if you want 4 concurrent scripts use WORKER_COUNT=4
# and WORKER_ID from 0 to 3

MIN_IMAGE_PIXELS = 500_000 # 0.5 megapixels
DEFAULT_IMAGE_PIXELS = 1_000_000 # 1 megapixel

MAX_IMAGE_PIXELS = [
  ARGV[0]&.to_i || DEFAULT_IMAGE_PIXELS,
  MIN_IMAGE_PIXELS
].max

ENV["VERBOSE"] = "1" if ENV["INTERACTIVE"]

def log(*args)
  puts(*args) if ENV["VERBOSE"]
end

def transform_post(post, upload_before, upload_after)
  post.raw.gsub!(/upload:\/\/#{upload_before.base62_sha1}(\.#{upload_before.extension})?/i, upload_after.short_url)
  post.raw.gsub!(Discourse.store.cdn_url(upload_before.url), Discourse.store.cdn_url(upload_after.url))
  post.raw.gsub!(Discourse.store.url_for(upload_before), Discourse.store.url_for(upload_after))
  post.raw.gsub!("#{Discourse.base_url}#{upload_before.short_path}", "#{Discourse.base_url}#{upload_after.short_path}")

  path = SiteSetting.Upload.s3_upload_bucket.split("/", 2)[1]
  post.raw.gsub!(/<img src=\"https:\/\/.+?\/#{path}\/uploads\/default\/optimized\/.+?\/#{upload_before.sha1}_\d_(?<width>\d+)x(?<height>\d+).*?\" alt=\"(?<alt>.*?)\"\/?>/i) do
    "![#{$~[:alt]}|#{$~[:width]}x#{$~[:height]}](#{upload_after.short_url})"
  end

  post.raw.gsub!(/!\[(.*?)\]\(\/uploads\/.+?\/#{upload_before.sha1}(\.#{upload_before.extension})?\)/i, "![\\1](#{upload_after.short_url})")
end

def downsize_upload(upload, path)
  # Make sure the filesize is up to date
  upload.filesize = File.size(path)

  OptimizedImage.downsize(path, path, "#{MAX_IMAGE_PIXELS}@", filename: upload.original_filename)
  sha1 = Upload.generate_digest(path)

  if sha1 == upload.sha1
    log "No sha1 change"
    return
  end

  w, h = FastImage.size(path, timeout: 15, raise_on_failure: true)

  if !w || !h
    log "Invalid image dimensions after resizing"
    return
  end

  # Neither #dup or #clone provide a complete copy
  original_upload = Upload.find(upload.id)
  ww, hh = ImageSizer.resize(w, h)

  # A different upload record that matches the sha1 of the downsized image
  existing_upload = Upload.find_by(sha1: sha1)
  upload = existing_upload if existing_upload

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
    return
  end

  unless existing_upload
    url = Discourse.store.store_upload(File.new(path), upload)

    unless url
      log "Couldn't store the upload"
      return
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

    if User.where(uploaded_avatar_id: original_upload.id).count
      log "Used as a User avatar"
    elsif UserAvatar.where(gravatar_upload_id: original_upload.id).count
      log "Used as a UserAvatar gravatar"
    elsif UserAvatar.where(custom_upload_id: original_upload.id).count
      log "Used as a UserAvatar custom upload"
    elsif UserProfile.where(profile_background_upload_id: original_upload.id).count
      log "Used as a UserProfile profile background"
    elsif UserProfile.where(card_background_upload_id: original_upload.id).count
      log "Used as a UserProfile card background"
    elsif Category.where(uploaded_logo_id: original_upload.id).count
      log "Used as a Category logo"
    elsif Category.where(uploaded_background_id: original_upload.id).count
      log "Used as a Category background"
    elsif CustomEmoji.where(upload_id: original_upload.id).count
      log "Used as a CustomEmoji"
    elsif ThemeField.where(upload_id: original_upload.id).count
      log "Used as a ThemeField"
    else
      success = false
    end
  end

  unless success
    if ENV["INTERACTIVE"]
      print "Press any key to continue with the upload"
      STDIN.beep
      STDIN.getch
      puts " k"
    elsif !existing_upload && !Upload.where(url: upload.url).exist?
      # We're bailing, so clean up the just uploaded file
      Discourse.store.remove_upload(upload)

      log "⏩ Skipping"
      return
    end
  end

  upload.save!

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

def process_uploads
  unless SiteSetting.Upload.enable_s3_uploads
    puts "This script supports only S3 uploads"
    return
  end

  puts "", "Downsizing images to no more than #{MAX_IMAGE_PIXELS} pixels"

  dimensions_count = 0
  downsized_count = 0

  scope = Upload.where("LOWER(extension) IN ('jpg', 'jpeg', 'gif', 'png')")
  scope = scope.where(<<-SQL, MAX_IMAGE_PIXELS)
    COALESCE(width, 0) = 0 OR
    COALESCE(height, 0) = 0 OR
    COALESCE(thumbnail_width, 0) = 0 OR
    COALESCE(thumbnail_height, 0) = 0 OR
    width * height > ?
  SQL

  if ENV["WORKER_ID"] && ENV["WORKER_COUNT"]
    scope = scope.where("id % ? = ?", ENV["WORKER_COUNT"], ENV["WORKER_ID"])
  end

  skipped = 0
  total_count = scope.count
  puts "Uploads to process: #{total_count}"

  scope.find_each.with_index do |upload, index|
    progress = (index * 100.0 / total_count).round(1)

    log "\n"
    print "\r#{progress}% Fixed dimensions: #{dimensions_count} Downsized: #{downsized_count} Skipped: #{skipped} (upload id: #{upload.id})"
    log "\n"

    source = upload.local? ? Discourse.store.path_for(upload) : "https:#{upload.url}"

    unless source
      log "No path or URL"
      skipped += 1
      next
    end

    begin
      w, h = FastImage.size(source, timeout: 15, raise_on_failure: true)
    rescue FastImage::ImageFetchFailure
      log "Retrying image resizing"
      w, h = FastImage.size(source, timeout: 15)
    rescue FastImage::UnknownImageType
      log "Unknown image type"
      skipped += 1
      next
    rescue FastImage::SizeNotFound
      log "Size not found"
      skipped += 1
      next
    end

    if !w || !h
      log "Invalid image dimensions"
      skipped += 1
      next
    end

    ww, hh = ImageSizer.resize(w, h)

    if w == 0 || h == 0 || ww == 0 || hh == 0
      log "Invalid image dimensions"
      skipped += 1
      next
    end

    upload.attributes = {
      width: w,
      height: h,
      thumbnail_width: ww,
      thumbnail_height: hh
    }

    if upload.changed?
      log "Correcting the upload dimensions"
      log "Before: #{upload.width_was}x#{upload.height_was} #{upload.thumbnail_width_was}x#{upload.thumbnail_height_was}"
      log "After:  #{w}x#{h} #{ww}x#{hh}"

      dimensions_count += 1
      upload.save!
    end

    if w * h < MAX_IMAGE_PIXELS
      log "Image size within allowed range"
      skipped += 1
      next
    end

    path = upload.local? ? source : (Discourse.store.download(upload) rescue nil)&.path

    unless path
      log "No image path"
      skipped += 1
      next
    end

    if downsize_upload(upload, path)
      downsized_count += 1
    else
      skipped += 1
    end
  end

  STDIN.beep
  puts "", "Done", Time.zone.now
end

process_uploads
