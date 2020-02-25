# frozen_string_literal: true

require File.expand_path("../../config/environment", __FILE__)

# no less than 1 megapixel
max_image_pixels = [ARGV[0].to_i, 1_000_000].max

puts "", "Downsizing images to no more than #{max_image_pixels} pixels"

dimensions_count = 0
downsized_count = 0

def downsize_upload(upload, path, max_image_pixels)
  # Make sure the filesize is up to date
  upload.filesize = File.size(path)

  OptimizedImage.downsize(path, path, "#{max_image_pixels}@", filename: upload.original_filename)
  sha1 = Upload.generate_digest(path)

  if sha1 == upload.sha1
    puts "no sha1 change" if ENV["VERBOSE"]
    return
  end

  w, h = FastImage.size(path, timeout: 10, raise_on_failure: true)

  if !w || !h
    puts "invalid image dimensions after resizing" if ENV["VERBOSE"]
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
    puts "no filesize reduction" if ENV["VERBOSE"]
    return
  end

  upload.sha1 = sha1
  upload.width = w
  upload.height = h
  upload.thumbnail_width = ww
  upload.thumbnail_height = hh

  if new_file
    url = Discourse.store.store_upload(File.new(path), upload)

    unless url
      puts "couldn't store the upload" if ENV["VERBOSE"]
      return
    end

    upload.url = url
  end

  if ENV["VERBOSE"]
    puts "base62: #{original_upload.base62_sha1} -> #{Upload.base62_sha1(sha1)}"
    puts "sha1: #{original_upload.sha1} -> #{sha1}"
    puts "is a new file: #{new_file}"
  end

  upload.save!

  if new_file
    upload.optimized_images.each(&:destroy!)
    Discourse.store.remove_upload(original_upload)
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

  original_upload.posts.each do |post|
    post.raw.gsub!(/upload:\/\/#{original_upload.base62_sha1}(\.#{original_upload.extension})?/, upload.short_url)
    post.raw.gsub!(Discourse.store.cdn_url(original_upload.url), Discourse.store.cdn_url(upload.url))

    if post.raw_changed?
      puts "updating post #{post.id}" if ENV["VERBOSE"]
      post.save!
    else
      puts "Could find the upload path in post.raw (post_id: #{post.id})" if ENV["VERBOSE"]
    end

    post.rebake!
  end

  original_upload.reload.destroy! unless new_file

  puts "" if ENV["VERBOSE"]

  true
end

scope = Upload
  .where("LOWER(extension) IN ('jpg', 'jpeg', 'gif', 'png')")
  .where("COALESCE(width, 0) = 0 OR COALESCE(height, 0) = 0 OR COALESCE(thumbnail_width, 0) = 0 OR COALESCE(thumbnail_height, 0) = 0 OR width * height > ?", max_image_pixels)

puts "Uploads to process: #{scope.count}"

scope.find_each do |upload|
  print "\rFixed dimensions: %8d        Downsized: %8d (upload id: #{upload.id})".freeze % [dimensions_count, downsized_count]
  puts "\n" if ENV["VERBOSE"]

  source = upload.local? ? Discourse.store.path_for(upload) : "https:#{upload.url}"

  unless source
    puts "no path or URL" if ENV["VERBOSE"]
    next
  end

  w, h = FastImage.size(source, timeout: 10)

  if !w || !h
    puts "invalid image dimensions" if ENV["VERBOSE"]
    next
  end

  ww, hh = ImageSizer.resize(w, h)

  if w == 0 || h == 0 || ww == 0 || hh == 0
    puts "invalid image dimensions" if ENV["VERBOSE"]
    next
  end

  if upload.read_attribute(:width) != w || upload.read_attribute(:height) != h || upload.read_attribute(:thumbnail_width) != ww || upload.read_attribute(:thumbnail_height) != hh
    puts "Correcting the upload dimensions" if ENV["VERBOSE"]
    dimensions_count += 1

    upload.update!(
      width: w,
      height: h,
      thumbnail_width: ww,
      thumbnail_height: hh,
    )
  end

  if w * h < max_image_pixels
    puts "image size within allowed range" if ENV["VERBOSE"]
    next
  end

  path = upload.local? ? source : (Discourse.store.download(upload) rescue nil)&.path

  unless path
    puts "no image path" if ENV["VERBOSE"]
    next
  end

  downsized_count += 1 if downsize_upload(upload, path, max_image_pixels)
end

puts "", "Done"
