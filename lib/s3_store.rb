module S3Store

  def self.store_file(file, sha1, upload_id)
    S3Store.check_missing_site_settings

    directory = S3Store.get_or_create_directory(SiteSetting.s3_upload_bucket)
    extension = File.extname(file.original_filename)
    remote_filename = "#{upload_id}#{sha1}#{extension}"

    # if this fails, it will throw an exception
    file = S3Store.upload(file, remote_filename, directory)
    "#{S3Store.base_url}/#{remote_filename}"
  end

  def self.base_url
    "//#{SiteSetting.s3_upload_bucket.downcase}.s3.amazonaws.com"
  end

  def self.remove_file(url)
    S3Store.check_missing_site_settings

    directory = S3Store.get_or_create_directory(SiteSetting.s3_upload_bucket)

    file = S3Store.destroy(url, directory)
  end

  def self.check_missing_site_settings
    raise Discourse::SiteSettingMissing.new("s3_upload_bucket")     if SiteSetting.s3_upload_bucket.blank?
    raise Discourse::SiteSettingMissing.new("s3_access_key_id")     if SiteSetting.s3_access_key_id.blank?
    raise Discourse::SiteSettingMissing.new("s3_secret_access_key") if SiteSetting.s3_secret_access_key.blank?
  end

  def self.get_or_create_directory(name)
    @fog_loaded = require 'fog' unless @fog_loaded

    options = S3Store.generate_options

    fog = Fog::Storage.new(options)

    directory = fog.directories.get(name)
    directory = fog.directories.create(key: name) unless directory

    directory
  end

  def self.generate_options
    options = {
      provider: 'AWS',
      aws_access_key_id: SiteSetting.s3_access_key_id,
      aws_secret_access_key: SiteSetting.s3_secret_access_key
    }
    options[:region] = SiteSetting.s3_region unless SiteSetting.s3_region.empty?

    options
  end

  def self.upload(file, name, directory)
    directory.files.create(
      key: name,
      public: true,
      body: file.tempfile,
      content_type: file.content_type
    )
  end

  def self.destroy(name, directory)
    directory.files.destroy(key: name)
  end

end
