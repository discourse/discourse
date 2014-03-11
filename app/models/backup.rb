class Backup
  include UrlHelper
  include ActiveModel::SerializerSupport

  attr_reader :filename
  attr_accessor :size, :path, :link

  def initialize(filename)
    @filename = filename
  end

  def self.all
    backups = Dir.glob(File.join(Backup.base_directory, "*.tar.gz"))
    backups.sort.reverse.map { |backup| Backup.create_from_filename(File.basename(backup)) }
  end

  def self.[](filename)
    path = File.join(Backup.base_directory, filename)
    if File.exists?(path)
      Backup.create_from_filename(filename)
    else
      nil
    end
  end

  def remove
    File.delete(@path) if File.exists?(path)
  end

  def self.base_directory
    @base_directory ||= File.join(Rails.root, "public", "backups", RailsMultisite::ConnectionManagement.current_db)
  end

  def self.chunk_path(identifier, filename, chunk_number)
    File.join(Backup.base_directory, "tmp", identifier, "#{filename}.part#{chunk_number}")
  end

  def self.create_from_filename(filename)
    Backup.new(filename).tap do |b|
      b.path = File.join(Backup.base_directory, b.filename)
      b.link = b.schemaless "#{Discourse.base_url}/admin/backups/#{b.filename}"
      b.size = File.size(b.path)
    end
  end

  def self.remove_old
    all_backups = Backup.all
    return unless all_backups.size > SiteSetting.maximum_backups
    all_backups[SiteSetting.maximum_backups..-1].each {|b| b.remove}
  end

end
