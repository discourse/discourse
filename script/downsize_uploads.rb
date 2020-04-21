# frozen_string_literal: true

require File.expand_path("../../config/environment", __FILE__)

# no less than 1 megapixel
MAX_IMAGE_PIXELS = [ARGV[0].to_i, 1_000_000].max

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
  new_file = true

  if existing_upload = Upload.find_by(sha1: sha1)
    upload = existing_upload
    new_file = false
  end

  before = upload.filesize
  upload.filesize = File.size(path)

  if upload.filesize > before
    puts "No filesize reduction" if ENV["VERBOSE"]
    return
  end

  upload.attributes = {
    sha1: sha1,
    width: w,
    height: h,
    thumbnail_width: ww,
    thumbnail_height: hh
  }

  if new_file
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
    puts "Is a new file: #{new_file}"
  end

  success = true
  posts = Post.unscoped.joins(:post_uploads).where(post_uploads: { upload_id: original_upload.id }).uniq.sort_by(&:created_at)

  posts.each do |post|
    transform_post(post, original_upload, upload)

    if post.raw_changed?
      puts "Updating post #{post.id}" if ENV["VERBOSE"]
    elsif post.cooked.include?(original_upload.sha1)
      if post.raw.include?("#{Discourse.base_url.sub(/^https?:\/\//i, "")}/t/")
        puts "Updating a topic onebox in post #{post.id}" if ENV["VERBOSE"]
      else
        puts "Updating an external onebox in post #{post.id}" if ENV["VERBOSE"]
      end
    elsif post.raw.include?(upload.short_url)
      puts "Already processed"
    elsif !post.trashed? && post.topic
      # Ignore issues with deleted posts and deleted topics
      puts "Could not find the upload URL in post #{post.id}" if ENV["VERBOSE"]
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
    elsif new_file && !Upload.where(url: upload.url).exist?
      # Clean up if we bail
      Discourse.store.remove_upload(upload)

      puts "Skipping" if ENV["VERBOSE"]
      return
    end
  end

  upload.save!

  if new_file
    upload.optimized_images.each(&:destroy!)
  else
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
  end

  posts.each do |post|
    DistributedMutex.synchronize("process_post_#{post.id}") do
      current_post = Post.unscoped.find(post.id)

      # If the post got outdated, re-apply changes
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

      post.rebake!
    end
  end

  if new_file
    Discourse.store.remove_upload(original_upload)
  else
    original_upload.reload.destroy!
  end

  true
end

def process_uploads
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

  puts "Uploads to process: #{scope.count}"

  scope.find_each do |upload|
    puts "\n" if ENV["VERBOSE"]
    print "\rFixed dimensions: #{dimensions_count} Downsized: #{downsized_count} (upload id: #{upload.id})"
    puts "\n" if ENV["VERBOSE"]

    source = upload.local? ? Discourse.store.path_for(upload) : "https:#{upload.url}"

    unless source
      puts "No path or URL" if ENV["VERBOSE"]
      next
    end

    begin
      w, h = FastImage.size(source, timeout: 15, raise_on_failure: true)
    rescue FastImage::ImageFetchFailure
      puts "Retrying image resizing"
      w, h = FastImage.size(source, timeout: 15)
    rescue FastImage::UnknownImageType
      puts "Unknown image type" if ENV["VERBOSE"]
      next
    rescue FastImage::SizeNotFound
      puts "Size not found" if ENV["VERBOSE"]
      next
    end

    if !w || !h
      puts "Invalid image dimensions" if ENV["VERBOSE"]
      next
    end

    ww, hh = ImageSizer.resize(w, h)

    if w == 0 || h == 0 || ww == 0 || hh == 0
      puts "Invalid image dimensions" if ENV["VERBOSE"]
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
        puts "Before: #{upload.read_attribute(:width)}x#{upload.read_attribute(:height)} #{upload.read_attribute(:thumbnail_width)}x#{upload.read_attribute(:thumbnail_height)}"
        puts "After:  #{w}x#{h} #{ww}x#{hh}"
      end

      dimensions_count += 1
      upload.save!
    end

    if w * h < MAX_IMAGE_PIXELS
      puts "Image size within allowed range" if ENV["VERBOSE"]
      next
    end

    path = upload.local? ? source : (Discourse.store.download(upload) rescue nil)&.path

    unless path
      puts "No image path" if ENV["VERBOSE"]
      next
    end

    downsized_count += 1 if downsize_upload(upload, path)
  end

  STDIN.beep
  puts "", "Done", Time.zone.now
end

process_uploads
