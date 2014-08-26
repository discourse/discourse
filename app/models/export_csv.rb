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
    if Dir.exists?(ExportCsv.base_directory)
      Dir.foreach(ExportCsv.base_directory) do |file|
        path = File.join(ExportCsv.base_directory, file)
        next if File.directory? path

        if (File.mtime(path) < 2.days.ago)
          File.delete(path)
        end
      end
    end
  end

  def self.base_directory
    File.join(Rails.root, "public", "uploads", "csv_exports", RailsMultisite::ConnectionManagement.current_db)
  end

end
