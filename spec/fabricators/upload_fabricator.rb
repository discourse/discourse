Fabricator(:upload) do
  user
  sha1 { sequence(:sha1) { |n| Digest::SHA1.hexdigest(n.to_s) } }
  original_filename "logo.png"
  filesize 1234
  width 100
  height 200
  url { sequence(:url) { |n| "/uploads/default/#{n}/1234567890123456.png" } }
  extension "png"
end

Fabricator(:upload_s3, from: :upload) do
  url { sequence(:url) { |n| "#{Discourse.store.absolute_base_url}/uploads/default/#{n}/1234567890123456.png" } }
end

Fabricator(:attachment, from: :upload) do
  id 42
  user
  original_filename "archive.zip"
  filesize 1234
  url "/uploads/default/42/66b3ed1503efc936.zip"
end
