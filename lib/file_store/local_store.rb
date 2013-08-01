class LocalStore

  def store_upload(file, upload)
    unique_sha1 = Digest::SHA1.hexdigest("#{Time.now.to_s}#{file.original_filename}")[0,16]
    extension = File.extname(file.original_filename)
    clean_name = "#{unique_sha1}#{extension}"
    path = "#{relative_base_url}/#{upload.id}/#{clean_name}"
    # copy the file to the right location
    copy_file(file, "#{public_dir}#{path}")
    # url
    Discourse.base_uri + path
  end

  def store_optimized_image(file, optimized_image)
    # 1234567890ABCDEF_100x200.jpg
    filename = [
      optimized_image.sha1[6..16],
      "_#{optimized_image.width}x#{optimized_image.height}",
      optimized_image.extension,
    ].join
    # <rails>/public/uploads/site/_optimized/123/456/<filename>
    path = File.join(
      relative_base_url,
      "_optimized",
      optimized_image.sha1[0..2],
      optimized_image.sha1[3..5],
      filename
    )
    # copy the file to the right location
    copy_file(file, "#{public_dir}#{path}")
    # url
    Discourse.base_uri + path
  end

  def remove_file(url)
    File.delete("#{public_dir}#{url}") if has_been_uploaded?(url)
  rescue Errno::ENOENT
    # don't care if the file isn't there
  end

  def has_been_uploaded?(url)
    is_relative?(url) || is_local?(url)
  end

  def absolute_base_url
    url = asset_host.present? ? asset_host : Discourse.base_url_no_prefix
    "#{url}#{relative_base_url}"
  end

  def relative_base_url
    "/uploads/#{RailsMultisite::ConnectionManagement.current_db}"
  end

  def external?
    !internal?
  end

  def internal?
    true
  end

  def path_for(upload)
    "#{public_dir}#{upload.url}"
  end

  private

  def copy_file(file, path)
    FileUtils.mkdir_p Pathname.new(path).dirname
    # move the file to the right location
    # not using cause mv, cause permissions are no good on move
    File.open(path, "wb") do |f|
      f.write(file.read)
    end
  end

  def is_relative?(url)
    url.start_with?(relative_base_url)
  end

  def is_local?(url)
    url.start_with?(absolute_base_url)
  end

  def public_dir
    "#{Rails.root}/public"
  end

  def asset_host
    Rails.configuration.action_controller.asset_host
  end

end
