Fabricator(:upload) do
  user
  original_filename "uploaded.jpg"
  filesize 1234
  width 100
  height 200
  url  "/uploads/default/1/1234567890123456.jpg"
end
