# frozen_string_literal: true

require File.expand_path("../../config/environment", __FILE__)

# no less than 1 megapixel
max_image_pixels = [ARGV[0].to_i, 1_000_000].max

puts "", "Downsizing images to no more than #{max_image_pixels} pixels"

count = 0

def downsize_upload(upload, path, max_image_pixels)
  OptimizedImage.downsize(path, path, "#{max_image_pixels}@", filename: upload.original_filename)

  # Neither #dup or #clone provide a complete copy
  original_upload = Upload.find(upload.id)

  sha1 = Upload.generate_digest(path)
  w, h = FastImage.size(path)
  ww, hh = ImageSizer.resize(w, h)

  new_file = true

  if existing_upload = Upload.find_by(sha1: sha1)
    upload = existing_upload
    new_file = false
  end

  upload.filesize = File.size(path)
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

  original_upload.posts.each do |post|
    post.update!(raw: post.raw.gsub(original_upload.short_url, upload.short_url))
    Jobs.enqueue(:process_post, post_id: post.id, bypass_bump: true, cook: true)
  end

  if new_file
    Discourse.store.remove_upload(original_upload)
  else
    User.where(uploaded_avatar_id: original_upload.id).update_all(uploaded_avatar_id: upload.id)
    UserAvatar.where(gravatar_upload_id: original_upload.id).update_all(gravatar_upload_id: upload.id)
    UserAvatar.where(custom_upload_id: original_upload.id).update_all(custom_upload_id: upload.id)

    original_upload.destroy!
  end
end

Upload
  .where("LOWER(extension) IN ('jpg', 'jpeg', 'gif', 'png')")
  .where("COALESCE(width, 0) = 0 OR COALESCE(height, 0) = 0 OR COALESCE(thumbnail_width, 0) = 0 OR COALESCE(thumbnail_height, 0) = 0 OR width * height > ?", max_image_pixels)
  .find_each do |upload|

  count += 1
  print "\r%8d".freeze % count

  next unless source = upload.local? ? Discourse.store.path_for(upload) : "https:#{upload.url}"

  w, h = FastImage.size(source)
  ww, hh = ImageSizer.resize(w, h)

  next if w == 0 || h == 0 || ww == 0 || hh == 0

  upload.update!(
    width: w,
    height: h,
    thumbnail_width: ww,
    thumbnail_height: hh,
  )

  next if w * h < max_image_pixels
  next unless path = upload.local? ? source : (Discourse.store.download(upload) rescue nil)&.path

  downsize_upload(upload, path, max_image_pixels)
end

puts "", "Done"
