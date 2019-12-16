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

  # Neither #dup or #clone provide a complete copy
  original_upload = Upload.find(upload.id)

  sha1 = Upload.generate_digest(path)
  w, h = FastImage.size(path, timeout: 10, raise_on_failure: true)
  return if !w || !h
  return if sha1 == upload.sha1

  ww, hh = ImageSizer.resize(w, h)

  new_file = true

  if existing_upload = Upload.find_by(sha1: sha1)
    upload = existing_upload
    new_file = false
  end

  before = upload.filesize
  upload.filesize = File.size(path)
  return if upload.filesize > before

  upload.sha1 = sha1
  upload.width = w
  upload.height = h
  upload.thumbnail_width = ww
  upload.thumbnail_height = hh

  if new_file
    return unless url = Discourse.store.store_upload(File.new(path), upload)
    upload.url = url
  end

  upload.save!

  upload.optimized_images.each(&:destroy!) if new_file
  original_upload.posts.each do |post|
    post.update!(raw: post.raw.gsub(original_upload.short_url, upload.short_url))
    post.rebake!
  end

  if new_file
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

    original_upload.reload.destroy!
  end

  true
end

scope = Upload
  .where("LOWER(extension) IN ('jpg', 'jpeg', 'gif', 'png')")
  .where("COALESCE(width, 0) = 0 OR COALESCE(height, 0) = 0 OR COALESCE(thumbnail_width, 0) = 0 OR COALESCE(thumbnail_height, 0) = 0 OR width * height > ?", max_image_pixels)

puts "Uploads to process: #{scope.count}"

scope.find_each do |upload|
  print "\rFixed dimensions: %8d        Downsized: %8d (upload id: #{upload.id})".freeze % [dimensions_count, downsized_count]

  next unless source = upload.local? ? Discourse.store.path_for(upload) : "https:#{upload.url}"

  w, h = FastImage.size(source, timeout: 10)
  next if !w || !h

  ww, hh = ImageSizer.resize(w, h)
  next if w == 0 || h == 0 || ww == 0 || hh == 0

  if upload.read_attribute(:width) != w || upload.read_attribute(:height) != h || upload.read_attribute(:thumbnail_width) != ww || upload.read_attribute(:thumbnail_height) != hh
    dimensions_count += 1

    upload.update!(
      width: w,
      height: h,
      thumbnail_width: ww,
      thumbnail_height: hh,
    )
  end

  next if w * h < max_image_pixels
  next unless path = upload.local? ? source : (Discourse.store.download(upload) rescue nil)&.path

  downsized_count += 1 if downsize_upload(upload, path, max_image_pixels)
end

puts "", "Done"
