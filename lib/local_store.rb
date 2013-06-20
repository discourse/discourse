module LocalStore

  def self.store_file(file, sha1, image_info, upload_id)
    clean_name = Digest::SHA1.hexdigest("#{Time.now.to_s}#{file.original_filename}")[0,16] + ".#{image_info.type}"
    url_root = "/uploads/#{RailsMultisite::ConnectionManagement.current_db}/#{upload_id}"
    path = "#{Rails.root}/public#{url_root}"

    FileUtils.mkdir_p path
    # not using cause mv, cause permissions are no good on move
    File.open("#{path}/#{clean_name}", "wb") do |f|
      f.write File.read(file.tempfile)
    end

    # url
    return Discourse::base_uri + "#{url_root}/#{clean_name}"
  end

  def self.remove_file(url)
    File.delete("#{Rails.root}/public#{url}")
  rescue Errno::ENOENT
  end

end
