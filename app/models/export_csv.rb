class ExportCsv

  def self.get_download_path(filename)
    path = File.join(ExportCsv.base_directory, filename)
    if File.exists?(path)
      return path
    else
      nil
    end
  end

  def self.remove_old_exports
    dir = Dir.new(ExportCsv.base_directory)
    dir.each do |file|
      if (File.mtime(File.join(ExportCsv.base_directory, file)) < 2.days.ago)
        File.delete(File.join(ExportCsv.base_directory, file))
      end
    end
  end

  def self.base_directory
    File.join(Rails.root, "public", "uploads", "csv_exports", RailsMultisite::ConnectionManagement.current_db)
  end

end
