class LocalStore

  def store_upload(file, upload)
    path = get_path_for_upload(file, upload)
    store_file(file, path)
  end

  def store_optimized_image(file, optimized_image)
    path = get_path_for_optimized_image(file, optimized_image)
    store_file(file, path)
  end

  def store_avatar(file, upload, size)
    path = get_path_for_avatar(file, upload, size)
    store_file(file, path)
  end

  def remove_upload(upload)
    remove_file(upload.url)
  end

  def remove_optimized_image(optimized_image)
    remove_file(optimized_image.url)
  end

  def remove_avatars(upload)
    return unless upload.url =~ /avatars/
    remove_directory(File.dirname(upload.url))
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

  def absolute_avatar_template(upload)
    avatar_template(upload, absolute_base_url)
  end

  private

  def get_path_for_upload(file, upload)
    unique_sha1 = Digest::SHA1.hexdigest("#{Time.now.to_s}#{file.original_filename}")[0..15]
    extension = File.extname(file.original_filename)
    clean_name = "#{unique_sha1}#{extension}"
    # path
    "#{relative_base_url}/#{upload.id}/#{clean_name}"
  end

  def get_path_for_optimized_image(file, optimized_image)
    # 1234567890ABCDEF_100x200.jpg
    filename = [
      optimized_image.sha1[6..15],
      "_#{optimized_image.width}x#{optimized_image.height}",
      optimized_image.extension,
    ].join
    # /uploads/<site>/_optimized/<1A3>/<B5C>/<filename>
    File.join(
      relative_base_url,
      "_optimized",
      optimized_image.sha1[0..2],
      optimized_image.sha1[3..5],
      filename
    )
  end

  def get_path_for_avatar(file, upload, size)
    relative_avatar_template(upload).gsub("{size}", size.to_s)
  end

  def relative_avatar_template(upload)
    avatar_template(upload, relative_base_url)
  end

  def avatar_template(upload, base_url)
    File.join(
      base_url,
      "avatars",
      upload.sha1[0..2],
      upload.sha1[3..5],
      upload.sha1[6..15],
      "{size}#{upload.extension}"
    )
  end

  def store_file(file, path)
    # copy the file to the right location
    copy_file(file, "#{public_dir}#{path}")
    # url
    Discourse.base_uri + path
  end

  def copy_file(file, path)
    FileUtils.mkdir_p Pathname.new(path).dirname
    # move the file to the right location
    # not using cause mv, cause permissions are no good on move
    File.open(path, "wb") do |f|
      f.write(file.read)
    end
  end

  def remove_file(url)
    File.delete("#{public_dir}#{url}") if has_been_uploaded?(url)
  rescue Errno::ENOENT
    # don't care if the file isn't there
  end

  def remove_directory(path)
    directory = "#{public_dir}/#{path}"
    FileUtils.rm_rf(directory)
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
