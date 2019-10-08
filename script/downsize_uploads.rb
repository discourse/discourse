# frozen_string_literal: true

require File.expand_path("../../config/environment", __FILE__)

# no less than 1 megapixel
max_image_pixels = [ARGV[0].to_i, 1_000_000].max

puts '', "Downsizing uploads size to no more than #{max_image_pixels} pixels"

count = 0

Upload.where("LOWER(extension) IN ('jpg', 'jpeg', 'gif', 'png')").find_each do |upload|
  count += 1
  print "\r%8d".freeze % count

  next unless source = upload.local? ? Discourse.store.path_for(upload) : "https:#{upload.url}"
  next unless size = (FastImage.size(source) rescue nil)
  next if size.reduce(:*) < max_image_pixels
  next unless path = upload.local? ? source : (Discourse.store.download(upload) rescue nil)&.path

  OptimizedImage.downsize(path, path, "#{max_image_pixels}@", filename: upload.original_filename)

  previous_short_url = upload.short_url

  upload.filesize = File.size(path)
  upload.sha1 = Upload.generate_digest(path)
  upload.width, upload.height = ImageSizer.resize(*FastImage.size(path))
  next unless upload.save!

  next unless url = Discourse.store.store_upload(File.new(path), upload)
  next unless upload.update!(url: url)

  upload.posts.each do |post|
    post.update!(raw: post.raw.gsub(previous_short_url, upload.short_url))
    Jobs.enqueue(:process_post, post_id: post.id, bypass_bump: true, cook: true)
  end
end

puts '', 'Done', ''
