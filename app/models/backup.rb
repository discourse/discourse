class Backup
  include UrlHelper
  include ActiveModel::SerializerSupport

  attr_reader :filename, :size, :path, :link

  def initialize(filename)
    @filename = filename
    @path = File.join(Backup.base_directory, filename)
    @link = schemaless "#{Discourse.base_url}/admin/backups/#{filename}"
    @size = File.size(@path)
  end

  def self.all
    backups = Dir.glob(File.join(Backup.base_directory, "*.tar.gz"))
    backups.sort.reverse.map { |backup| Backup.new(File.basename(backup)) }
  end

  def self.[](filename)
    path = File.join(Backup.base_directory, filename)
    if File.exists?(path)
      Backup.new(filename)
    else
      nil
    end
  end

  def self.remove(filename)
    path = File.join(Backup.base_directory, filename)
    File.delete(path) if File.exists?(path)
  end

  def self.base_directory
    @base_directory ||= File.join(Rails.root, "public", "backups", RailsMultisite::ConnectionManagement.current_db)
  end

end
