module S3

  def self.store_file(file, image_info, upload_id)
    raise Discourse::SiteSettingMissing.new("s3_upload_bucket")     if SiteSetting.s3_upload_bucket.blank?
    raise Discourse::SiteSettingMissing.new("s3_access_key_id")     if SiteSetting.s3_access_key_id.blank?
    raise Discourse::SiteSettingMissing.new("s3_secret_access_key") if SiteSetting.s3_secret_access_key.blank?

    @fog_loaded = require 'fog' unless @fog_loaded

    blob = file.read
    sha1 = Digest::SHA1.hexdigest(blob)
    remote_filename = "#{upload_id}#{sha1}.#{image_info.type}"

    options = S3.generate_options
    directory = S3.get_or_create_directory(SiteSetting.s3_upload_bucket, options)
    # if this fails, it will throw an exception
    file = S3.upload(file, remote_filename, directory)

    return "//#{SiteSetting.s3_upload_bucket}.s3.amazonaws.com/#{remote_filename}"
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

  def self.get_or_create_directory(name, options)
    fog = Fog::Storage.new(options)
    directory = fog.directories.get(name)
    directory = fog.directories.create(key: name) unless directory

    directory
  end

  def self.upload(file, name, directory)
    directory.files.create(
      key: name,
      public: true,
      body: file.tempfile,
      content_type: file.content_type
    )
  end

end
