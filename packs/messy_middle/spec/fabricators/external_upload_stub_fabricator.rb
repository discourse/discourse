# frozen_string_literal: true

Fabricator(:external_upload_stub) do
  transient :folder_prefix

  created_by { Fabricate(:user) }
  original_filename "test.txt"
  key do |attrs|
    FileStore::BaseStore.temporary_upload_path(
      "test.txt",
      folder_prefix: attrs[:folder_prefix] || "",
    )
  end
  upload_type "card_background"
  filesize 1024
  status 1
end

Fabricator(:image_external_upload_stub, from: :external_upload_stub) do
  original_filename "logo.png"
  filesize 1024
  key do |attrs|
    FileStore::BaseStore.temporary_upload_path(
      "logo.png",
      folder_prefix: attrs[:folder_prefix] || "",
    )
  end
end

Fabricator(:attachment_external_upload_stub, from: :external_upload_stub) do
  original_filename "file.pdf"
  filesize 1024
  key do |attrs|
    FileStore::BaseStore.temporary_upload_path(
      "file.pdf",
      folder_prefix: attrs[:folder_prefix] || "",
    )
  end
end

Fabricator(:multipart_external_upload_stub, from: :external_upload_stub) do
  multipart true
  external_upload_identifier do
    "#{SecureRandom.hex(6)}._#{SecureRandom.hex(6)}_#{SecureRandom.hex(6)}.d.ghQ"
  end
end
