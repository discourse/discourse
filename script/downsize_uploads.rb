# frozen_string_literal: true

require File.expand_path("../../config/environment", __FILE__)

# no less than 1 megapixel
max_image_pixels = [ARGV[0].to_i, 1_000_000].max

puts "", "Fixing all images dimensions in the database", ""

count = 0

Upload
  .where("LOWER(extension) IN ('jpg', 'jpeg', 'gif', 'png')")
  .where("COALESCE(width, 0) = 0 OR COALESCE(height, 0) = 0 OR COALESCE(thumbnail_width, 0) = 0 OR COALESCE(thumbnail_height, 0) = 0")
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
end

puts "", "Downsizing images to no more than #{max_image_pixels} pixels"

count = 0

Upload
  .where("LOWER(extension) IN ('jpg', 'jpeg', 'gif', 'png')")
  .where("width * height > ?", max_image_pixels)
  .find_each do |upload|

  count += 1
  print "\r%8d".freeze % count

  next unless source = upload.local? ? Discourse.store.path_for(upload) : "https:#{upload.url}"
  next unless size = (FastImage.size(source) rescue nil)

  if size.reduce(:*) < max_image_pixels
    ww, hh = ImageSizer.resize(*size)

    upload.update!(
      width: size[0],
      height: size[1],
      thumbnail_width: ww,
      thumbnail_height: hh,
    )

    next
  end

  next unless path = upload.local? ? source : (Discourse.store.download(upload) rescue nil)&.path

  OptimizedImage.downsize(path, path, "#{max_image_pixels}@", filename: upload.original_filename)

  previous_short_url = upload.short_url

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
  next unless upload.save!

  if new_file
    next unless url = Discourse.store.store_upload(File.new(path), upload)
    next unless upload.update!(url: url)
  end

  upload.posts.each do |post|
    post.update!(raw: post.raw.gsub(previous_short_url, upload.short_url)) if new_file
    Jobs.enqueue(:process_post, post_id: post.id, bypass_bump: true, cook: true)
  end
end

puts "", "Done"
