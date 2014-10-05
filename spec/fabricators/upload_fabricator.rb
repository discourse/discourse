Fabricator(:upload) do
  user
  sha1 "e9d71f5ee7c92d6dc9e92ffdad17b8bd49418f98"
  original_filename "logo.png"
  filesize 1234
  width 100
  height 200
  url  "/uploads/default/1/1234567890123456.png"
end

Fabricator(:attachment, from: :upload) do
  id 42
  user
  original_filename "archive.zip"
  filesize 1234
  url  "/uploads/default/42/66b3ed1503efc936.zip"
end
