require "digest/sha1"

class OptimizedImage < ActiveRecord::Base
  belongs_to :upload

  def self.create_for(upload, width=nil, height=nil)
    @image_sorcery_loaded ||= require "image_sorcery"

    original_path = "#{Rails.root}/public#{upload.url}"
    # create a temp file with the same extension as the original
    temp_file = Tempfile.new(["discourse", File.extname(original_path)])
    temp_path = temp_file.path

    # do the resize when there is both dimensions
    if width && height && ImageSorcery.new(original_path).convert(temp_path, resize: "#{width}x#{height}")
      image_info = FastImage.new(temp_path)
      thumbnail = OptimizedImage.new({
        upload_id: upload.id,
        sha1: Digest::SHA1.file(temp_path).hexdigest,
        extension: File.extname(temp_path),
        width: image_info.size[0],
        height: image_info.size[1]
      })
      # make sure the directory exists
      FileUtils.mkdir_p Pathname.new(thumbnail.path).dirname
      # move the temp file to the right location
      File.open(thumbnail.path, "wb") do |f|
        f.write temp_file.read
      end
    end

    # close && remove temp file
    temp_file.close
    temp_file.unlink

    thumbnail
  end

  def url
    "#{Upload.base_url}/#{optimized_path}/#{filename}"
  end

  def path
    "#{path_root}/#{optimized_path}/#{filename}"
  end

  def path_root
    @path_root ||= "#{Rails.root}/public"
  end

  def optimized_path
    "uploads/#{RailsMultisite::ConnectionManagement.current_db}/_optimized/#{sha1[0..2]}/#{sha1[3..5]}"
  end

  def filename
    "#{sha1[6..16]}_#{width}x#{height}#{extension}"
  end

end

# == Schema Information
#
# Table name: optimized_images
#
#  id        :integer          not null, primary key
#  sha1      :string(40)       not null
#  extension :string(10)       not null
#  width     :integer          not null
#  height    :integer          not null
#  upload_id :integer          not null
#
# Indexes
#
#  index_optimized_images_on_upload_id                       (upload_id)
#  index_optimized_images_on_upload_id_and_width_and_height  (upload_id,width,height) UNIQUE
#

