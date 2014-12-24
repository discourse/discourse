class CsvExportLog < ActiveRecord::Base

  def self.get_download_path(filename)
    path = File.join(CsvExportLog.base_directory, filename)
    if File.exists?(path)
      return path
    else
      nil
    end
  end

  def self.remove_old_exports
    expired_exports = CsvExportLog.where('created_at < ?', 2.days.ago).to_a
    expired_exports.map do |expired_export|
      file_name = "export_#{expired_export.id}.csv"
      file_path = "#{CsvExportLog.base_directory}/#{file_name}"
      
      if File.exist?(file_path)
        File.delete(file_path)
      end
      CsvExportLog.find(expired_export.id).destroy
    end
  end

  def self.base_directory
    File.join(Rails.root, "public", "uploads", "csv_exports", RailsMultisite::ConnectionManagement.current_db)
  end

end

# == Schema Information
#
# Table name: csv_export_logs
#
#  id          :integer          not null, primary key
#  export_type :string(255)      not null
#  user_id     :integer          not null
#  created_at  :datetime
#  updated_at  :datetime
#
