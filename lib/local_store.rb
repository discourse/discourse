module LocalStore

  def self.store_file(file, sha1, upload_id)
    unique_sha1 = Digest::SHA1.hexdigest("#{Time.now.to_s}#{file.original_filename}")[0,16]
    extension = File.extname(file.original_filename)
    clean_name = "#{unique_sha1}#{extension}"
    url_root = "/uploads/#{RailsMultisite::ConnectionManagement.current_db}/#{upload_id}"
    path = "#{Rails.root}/public#{url_root}"

    FileUtils.mkdir_p path

    # not using cause mv, cause permissions are no good on move
    File.open("#{path}/#{clean_name}", "wb") do |f|
      f.write File.read(file.tempfile)
    end

    # url
    Discourse::base_uri + "#{url_root}/#{clean_name}"
  end

  def self.remove_file(url)
    File.delete("#{Rails.root}/public#{url}")
  rescue Errno::ENOENT
  end

  def self.uploaded_regex
    /\/uploads\/#{RailsMultisite::ConnectionManagement.current_db}\/(?<upload_id>\d+)\/[0-9a-f]{16}\.(png|jpg|jpeg|gif|tif|tiff|bmp)/
  end

  def self.base_url
    url = asset_host.present? ? asset_host : Discourse.base_url_no_prefix
    "#{url}#{directory}"
  end

  def self.base_path
    "#{Rails.root}/public#{directory}"
  end

  def self.directory
    "/uploads/#{RailsMultisite::ConnectionManagement.current_db}"
  end

  def self.asset_host
    ActionController::Base.asset_host
  end

end
