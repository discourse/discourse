# frozen_string_literal: true

Fabricator(:upload) do
  user
  sha1 { sequence(:sha1) { |n| Digest::SHA1.hexdigest("#{n}#{Process.pid}") } }
  original_filename "logo.png"
  filesize 1234
  width 100
  height 200
  thumbnail_width 30
  thumbnail_height 60

  url do |attrs|
    sequence(:url) do |n|
      Discourse.store.get_path_for("original", n + 1, attrs[:sha1], ".#{attrs[:extension]}")
    end
  end

  extension "png"
end

Fabricator(:large_image_upload, from: :upload) do
  width 2000
  height 2000
  after_create do |upload, _transients|
    file = file_from_fixtures("2000x2000.png")
    upload.url = Discourse.store.store_upload(file, upload)
    upload.sha1 = Upload.generate_digest(file)
  end
end

Fabricator(:image_upload, from: :upload) do
  transient color: "white"
  transient color_depth: 16

  after_create do |upload, transients|
    file = Tempfile.new(%w[fabricated .png])
    `convert -size #{upload.width}x#{upload.height} -depth #{transients[:color_depth]} xc:#{transients[:color]} "#{file.path}"`

    upload.url = Discourse.store.store_upload(file, upload)
    upload.sha1 = Upload.generate_digest(file.path)

    WebMock.stub_request(:get, "http://#{Discourse.current_hostname}#{upload.url}").to_return(
      status: 200,
      body: File.new(file.path),
    )
  end
end

Fabricator(:upload_no_dimensions, from: :upload) do
  width nil
  height nil
  thumbnail_width nil
  thumbnail_height nil
end

Fabricator(:video_upload, from: :upload) do
  original_filename "video.mp4"
  width nil
  height nil
  thumbnail_width nil
  thumbnail_height nil
  extension "mp4"
end

Fabricator(:secure_upload, from: :upload) do
  secure true
  sha1 { SecureRandom.hex(20) }
  original_sha1 { sequence(:sha1) { |n| Digest::SHA1.hexdigest(n.to_s) } }
end

Fabricator(:upload_s3, from: :upload) do
  url do |attrs|
    sequence(:url) do |n|
      path = +Discourse.store.get_path_for("original", n + 1, attrs[:sha1], ".#{attrs[:extension]}")

      path.prepend(File.join(Discourse.store.upload_path, "/")) if Rails.configuration.multisite

      File.join(Discourse.store.absolute_base_url, path)
    end
  end
end

Fabricator(:s3_image_upload, from: :upload_s3) do
  after_create do |upload|
    file = Tempfile.new(%w[fabricated .png])
    `convert -size #{upload.width}x#{upload.height} xc:white "#{file.path}"`

    upload.url = Discourse.store.store_upload(file, upload)
    upload.sha1 = Upload.generate_digest(file.path)

    WebMock.stub_request(:get, upload.url).to_return(status: 200, body: File.new(file.path))
  end
end

Fabricator(:secure_upload_s3, from: :upload_s3) do
  secure true
  sha1 { SecureRandom.hex(20) }
  original_sha1 { sequence(:sha1) { |n| Digest::SHA1.hexdigest(n.to_s) } }
end

Fabricator(:upload_reference) do
  target
  upload
end
