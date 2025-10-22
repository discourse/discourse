# frozen_string_literal: true

Fabricator(:optimized_video) do
  upload
  optimized_upload { Fabricate(:optimized_video_upload) }
  adapter "aws_mediaconvert"
end
