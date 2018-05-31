require File.expand_path("../../config/environment", __FILE__)

# no less than 1 megapixel
max_image_pixels = [ARGV[0].to_i, 1_000_000].max

puts '', "Downsizing uploads size to no more than #{max_image_pixels} pixels"

count = 0

Upload.where("lower(extension) in (?)", ['jpg', 'jpeg', 'gif', 'png', 'bmp', 'tif', 'tiff']).find_each do |upload|
  count += 1
  print "\r%8d".freeze % count
  absolute_path = Discourse.store.path_for(upload)
  if absolute_path && FileHelper.is_image?(upload.original_filename)
    file = File.new(absolute_path) rescue nil
    next unless file

    image_info = FastImage.new(file) rescue nil
    pixels = image_info.size&.reduce(:*).to_i

    if pixels > max_image_pixels
      OptimizedImage.downsize(file.path, file.path, "#{max_image_pixels}@", filename: upload.original_filename)

      upload.filesize = File.size(file)
      upload.width, upload.height = ImageSizer.resize(*FastImage.new(file).size)
      upload.save!

      upload.posts.each do |post|
        Jobs.enqueue(:process_post, post_id: post.id, bypass_bump: true, cook: true)
      end
    end
  end
end

puts '', 'Done', ''
