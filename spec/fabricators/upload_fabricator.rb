Fabricator(:upload) do
  user
  sha1 { sequence(:sha1) { |n| Digest::SHA1.hexdigest(n.to_s) } }
  original_filename "logo.png"
  filesize 1234
  width 100
  height 200
  thumbnail_width 30
  thumbnail_height 60

  url do |attrs|
    sequence(:url) do |n|
      Discourse.store.get_path_for(
        "original", n + 1, attrs[:sha1], ".#{attrs[:extension]}"
      )
    end
  end

  extension "png"
end

Fabricator(:upload_s3, from: :upload) do
  url do |attrs|
    sequence(:url) do |n|
      File.join(
        Discourse.store.absolute_base_url,
        Discourse.store.get_path_for(
          "original", n + 1, attrs[:sha1], ".#{attrs[:extension]}"
        )
      )
    end
  end
end
