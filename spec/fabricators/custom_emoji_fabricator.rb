# frozen_string_literal: true

Fabricator(:custom_emoji) do
  upload { Fabricate(:image_upload) }

  name { "joffrey_facepalm" }
end
