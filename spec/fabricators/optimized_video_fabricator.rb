# frozen_string_literal: true

Fabricator(:optimized_video) do
  upload
  sha1 { sequence(:sha1) { |i| Digest::SHA1.hexdigest(i.to_s) } }
  extension "mp4"
  url { |attrs| "//bucket.s3.region.amazonaws.com/optimized/videos/#{attrs[:sha1]}.mp4" }
  filesize { sequence(:filesize) { |i| 1000 + i } }
  etag { sequence(:etag) { |i| "etag#{i}" } }
end
