Fabricator(:optimized_image) do
  upload
  sha1 "abcdef"
  extension ".png"
  width 100
  height 200
end
