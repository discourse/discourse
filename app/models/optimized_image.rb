class OptimizedImage < ActiveRecord::Base
  belongs_to :upload

  def self.create_for(upload_id, path)
    image_info = FastImage.new(path)
    OptimizedImage.new({
      upload_id: upload_id,
      sha: Digest::SHA1.file(path).hexdigest,
      ext: File.extname(path),
      width: image_info.size[0],
      height: image_info.size[1]
    })
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
    "uploads/#{RailsMultisite::ConnectionManagement.current_db}/_optimized/#{sha[0..2]}/#{sha[3..5]}"
  end

  def filename
    "#{sha[6..16]}_#{width}x#{height}#{ext}"
  end

end
