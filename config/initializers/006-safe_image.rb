# frozen_string_literal: true

require "safe_image"

safe_image_backend = ENV.fetch("DISCOURSE_SAFE_IMAGE_BACKEND", "imagemagick").to_sym
safe_image_landlock =
  !%w[0 false no off].include?(ENV.fetch("DISCOURSE_SAFE_IMAGE_LANDLOCK", "1").downcase)

SafeImage.configure!(backend: safe_image_backend, landlock: safe_image_landlock)
