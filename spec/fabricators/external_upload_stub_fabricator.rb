# frozen_string_literal: true

Fabricator(:external_upload_stub) do
  created_by { Fabricate(:user) }
  original_filename "test.txt"
  key "path/to/s3/#{SecureRandom.hex(10)}/test.txt"
  upload_type "card_background"
  status 1
end

Fabricator(:image_external_upload_stub, from: :external_upload_stub) do
  original_filename "logo.png"
  key "path/to/s3/#{SecureRandom.hex(10)}/logo.png"
end

Fabricator(:attachment_external_upload_stub, from: :external_upload_stub) do
  original_filename "file.pdf"
  key "path/to/s3/#{SecureRandom.hex(10)}/file.pdf"
end
