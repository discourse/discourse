# frozen_string_literal: true

Fabricator(:optimized_image) do
  upload
  sha1 "86f7e437faa5a7fce15d1ddcb9eaeaea377667b8"
  extension ".png"
  width 100
  height 200
  version OptimizedImage::VERSION

  after_build do |optimized_image, _|
    unless optimized_image.url
      optimized_image.url = Discourse.store.get_path_for_optimized_image(optimized_image)
    end
  end
end
