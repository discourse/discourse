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
    after_remove_hook
  end

  def after_create_hook
    upload_to_s3 if SiteSetting.enable_s3_backups?
  end

  def after_remove_hook
    remove_from_s3 if SiteSetting.enable_s3_backups?
  end

  def upload_to_s3
    return unless fog_directory
    fog_directory.files.create(key: @filename, public: false, body: File.read(@path))
  end

  def remove_from_s3
    return unless fog
    fog.delete_object(SiteSetting.s3_backup_bucket, @filename)
  end

  def self.base_directory
    File.join(Rails.root, "public", "backups", RailsMultisite::ConnectionManagement.current_db)
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

  private

    def fog
      return @fog if @fog
      return unless SiteSetting.s3_access_key_id.present? &&
                    SiteSetting.s3_secret_access_key.present? &&
                    SiteSetting.s3_backup_bucket.present?
      require 'fog'
      @fog = Fog::Storage.new(provider: 'AWS',
                              aws_access_key_id: SiteSetting.s3_access_key_id,
                              aws_secret_access_key: SiteSetting.s3_secret_access_key)
    end

    def fog_directory
      return @fog_directory if @fog_directory
      return unless fog
      @fog_directory ||= fog.directories.get(SiteSetting.s3_backup_bucket)
    end

end
