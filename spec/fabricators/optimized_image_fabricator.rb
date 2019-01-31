Fabricator(:optimized_image) do
  upload
  sha1 "86f7e437faa5a7fce15d1ddcb9eaeaea377667b8"
  extension ".png"
  width 100
  height 200
  url "138569_100x200.png"
  version OptimizedImage::VERSION
end
