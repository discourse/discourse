Post.find_missing_uploads(include_local_upload: true) do |post, src, path, sha1|
  next if sha1.present?

  upload_id = nil

  # recovering old scheme upload.
  local_store = FileStore::LocalStore.new
  public_path = "#{local_store.public_dir}#{path}"
  file_path = nil

  if File.exists?(public_path)
    file_path = public_path
  else
    tombstone_path = public_path.sub("/uploads/", "/uploads/tombstone/")
    file_path = tombstone_path if File.exists?(tombstone_path)
  end

  if file_path.present?
    puts "file_path #{file_path} basename #{path}"

    if (upload = UploadCreator.new(File.open(file_path), File.basename(path)).create_for(Discourse.system_user.id)).persisted?
      upload_id = upload.id

      post.reload

      new_raw = post.raw.dup
      new_raw = new_raw.sub(path, upload.url)

      PostRevisor.new(post, Topic.with_deleted.find_by(id: post.topic_id)).revise!(
        Discourse.system_user,
        {
          raw: new_raw
        },
        skip_validations: true,
        force_new_version: true,
        bypass_bump: true
      )

      print "🆗"
    else
      print "🚫"
    end
  else
    print "❌"
  end

  upload_id
end
