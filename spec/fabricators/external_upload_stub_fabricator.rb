# frozen_string_literal: true

Fabricator(:external_upload_stub) do
  transient :folder_prefix

  created_by { Fabricate(:user) }
  original_filename "test.txt"
  key do |attrs|
    FileStore::BaseStore.temporary_upload_path(
      attrs[:original_filename],
      folder_prefix: attrs[:folder_prefix] || Discourse.store.upload_path,
    )
  end
  upload_type "card_background"
  filesize 1024
  status 1
end

Fabricator(:image_external_upload_stub, from: :external_upload_stub) do
  original_filename "logo.png"
  filesize 1024
end

Fabricator(:attachment_external_upload_stub, from: :external_upload_stub) do
  original_filename "file.pdf"
  filesize 1024
end

Fabricator(:multipart_external_upload_stub, from: :external_upload_stub) do
  multipart true
  external_upload_identifier do
    "#{SecureRandom.hex(6)}._#{SecureRandom.hex(6)}_#{SecureRandom.hex(6)}.d.ghQ"
  end
end
