class ExportCsv

  def self.get_download_path(filename)
    path = File.join(ExportCsv.base_directory, filename)
    if File.exists?(path)
      return path
    else
      nil
    end
  end

  def self.base_directory
    File.join(Rails.root, "public", "uploads", "csv_exports", RailsMultisite::ConnectionManagement.current_db)
  end

end
