# frozen_string_literal: true

require File.expand_path("../../config/environment", __FILE__)

MIN_IMAGE_PIXELS = 500_000 # 0.5 megapixels
DEFAULT_IMAGE_PIXELS = 1_000_000 # 1 megapixel

MAX_IMAGE_PIXELS = [
  ARGV[0]&.to_i || DEFAULT_IMAGE_PIXELS,
  MIN_IMAGE_PIXELS
].max

ENV["VERBOSE"] = "1" if ENV["INTERACTIVE"]

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
    puts "No sha1 change" if ENV["VERBOSE"]
    return
  end

  w, h = FastImage.size(path, timeout: 15, raise_on_failure: true)

  if !w || !h
    puts "Invalid image dimensions after resizing" if ENV["VERBOSE"]
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
    puts "No filesize reduction" if ENV["VERBOSE"]
    return
  end

  unless existing_upload
    url = Discourse.store.store_upload(File.new(path), upload)

    unless url
      puts "Couldn't store the upload" if ENV["VERBOSE"]
      return
    end

    upload.url = url
  end

  if ENV["VERBOSE"]
    puts "base62: #{original_upload.base62_sha1} -> #{Upload.base62_sha1(sha1)}"
    puts "sha: #{original_upload.sha1} -> #{sha1}"
    puts "(an exisiting upload)" if existing_upload
  end

  success = true
  posts = Post.unscoped.joins(:post_uploads).where(post_uploads: { upload_id: original_upload.id }).uniq.sort_by(&:created_at)

  posts.each do |post|
    transform_post(post, original_upload, upload)

    if post.custom_fields[Post::DOWNLOADED_IMAGES].present?
      downloaded_images = JSON.parse(post.custom_fields[Post::DOWNLOADED_IMAGES])
    end

    if post.raw_changed?
      puts "Updating post" if ENV["VERBOSE"]
    elsif downloaded_images&.has_value?(original_upload.id)
      puts "A hotlinked, unreferenced image" if ENV["VERBOSE"]
    elsif post.raw.include?(upload.short_url)
      puts "Already processed"
    elsif post.trashed?
      puts "A deleted post" if ENV["VERBOSE"]
    elsif !post.topic || post.topic.trashed?
      puts "A deleted topic" if ENV["VERBOSE"]
    elsif post.cooked.include?(original_upload.sha1)
      if post.raw.include?("#{Discourse.base_url.sub(/^https?:\/\//i, "")}/t/")
        puts "Updating a topic onebox" if ENV["VERBOSE"]
      else
        puts "Updating an external onebox" if ENV["VERBOSE"]
      end
    else
      puts "Could not find the upload URL" if ENV["VERBOSE"]
      success = false
    end

    puts "#{Discourse.base_url}/p/#{post.id}" if ENV["VERBOSE"]
  end

  if posts.empty?
    puts "Upload not used in any posts"

    if User.where(uploaded_avatar_id: original_upload.id).count
      puts "Used as a User avatar"
    elsif UserAvatar.where(gravatar_upload_id: original_upload.id).count
      puts "Used as a UserAvatar gravatar"
    elsif UserAvatar.where(custom_upload_id: original_upload.id).count
      puts "Used as a UserAvatar custom upload"
    elsif UserProfile.where(profile_background_upload_id: original_upload.id).count
      puts "Used as a UserProfile profile background"
    elsif UserProfile.where(card_background_upload_id: original_upload.id).count
      puts "Used as a UserProfile card background"
    elsif Category.where(uploaded_logo_id: original_upload.id).count
      puts "Used as a Category logo"
    elsif Category.where(uploaded_background_id: original_upload.id).count
      puts "Used as a Category background"
    elsif CustomEmoji.where(upload_id: original_upload.id).count
      puts "Used as a CustomEmoji"
    elsif ThemeField.where(upload_id: original_upload.id).count
      puts "Used as a ThemeField"
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

      puts "⏩ Skipping" if ENV["VERBOSE"]
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

    puts "\n" if ENV["VERBOSE"]
    print "\r#{progress}% Fixed dimensions: #{dimensions_count} Downsized: #{downsized_count} Skipped: #{skipped} (upload id: #{upload.id})"
    puts "\n" if ENV["VERBOSE"]

    source = upload.local? ? Discourse.store.path_for(upload) : "https:#{upload.url}"

    unless source
      puts "No path or URL" if ENV["VERBOSE"]
      skipped += 1
      next
    end

    begin
      w, h = FastImage.size(source, timeout: 15, raise_on_failure: true)
    rescue FastImage::ImageFetchFailure
      puts "Retrying image resizing" if ENV["VERBOSE"]
      w, h = FastImage.size(source, timeout: 15)
    rescue FastImage::UnknownImageType
      puts "Unknown image type" if ENV["VERBOSE"]
      skipped += 1
      next
    rescue FastImage::SizeNotFound
      puts "Size not found" if ENV["VERBOSE"]
      skipped += 1
      next
    end

    if !w || !h
      puts "Invalid image dimensions" if ENV["VERBOSE"]
      skipped += 1
      next
    end

    ww, hh = ImageSizer.resize(w, h)

    if w == 0 || h == 0 || ww == 0 || hh == 0
      puts "Invalid image dimensions" if ENV["VERBOSE"]
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
      if ENV["VERBOSE"]
        puts "Correcting the upload dimensions"
        puts "Before: #{upload.width_was}x#{upload.height_was} #{upload.thumbnail_width_was}x#{upload.thumbnail_height_was}"
        puts "After:  #{w}x#{h} #{ww}x#{hh}"
      end

      dimensions_count += 1
      upload.save!
    end

    if w * h < MAX_IMAGE_PIXELS
      puts "Image size within allowed range" if ENV["VERBOSE"]
      skipped += 1
      next
    end

    path = upload.local? ? source : (Discourse.store.download(upload) rescue nil)&.path

    unless path
      puts "No image path" if ENV["VERBOSE"]
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
