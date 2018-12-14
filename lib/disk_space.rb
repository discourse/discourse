class DiskSpace
  def self.uploads_used_bytes
    # used(uploads_path)
    # temporary (on our internal setup its just too slow to iterate)
    Upload.sum(:filesize).to_i
  end

  def self.uploads_free_bytes
    free(uploads_path)
  end

  def self.free(path)
    `df -Pk #{path} | awk 'NR==2 {print $4;}'`.to_i * 1024
  end

  def self.used(path)
    `du -s #{path}`.to_i * 1024
  end

  def self.uploads_path
    "#{Rails.root}/public/uploads/#{RailsMultisite::ConnectionManagement.current_db}"
  end
  private_class_method :uploads_path
end
