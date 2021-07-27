# frozen_string_literal: true

Fabricator(:external_upload_stub) do
  created_by { Fabricate(:user) }
  original_filename "test.txt"
  key { Discourse.store.temporary_upload_path("test.txt") }
  upload_type "card_background"
  status 1
end

Fabricator(:image_external_upload_stub, from: :external_upload_stub) do
  original_filename "logo.png"
  key { Discourse.store.temporary_upload_path("logo.png") }
end

Fabricator(:attachment_external_upload_stub, from: :external_upload_stub) do
  original_filename "file.pdf"
  key { Discourse.store.temporary_upload_path("file.pdf") }
end
