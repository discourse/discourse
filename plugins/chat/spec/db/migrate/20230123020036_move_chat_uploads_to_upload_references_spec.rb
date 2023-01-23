# frozen_string_literal: true

require Rails.root.join(
          "plugins/chat/db/migrate/20230123020036_move_chat_uploads_to_upload_references.rb",
        )

RSpec.describe MoveChatUploadsToUploadReferences do
  it "creates UploadReference records for all ChatUpload records" do
    chat_message_1 = Fabricate(:chat_message)
    chat_message_2 = Fabricate(:chat_message)
    chat_message_3 = Fabricate(:chat_message)
    chat_message_4 = Fabricate(:chat_message)

    upload_1 = Fabricate(:upload)
    upload_2 = Fabricate(:upload)
    upload_3 = Fabricate(:upload)
    upload_4 = Fabricate(:upload)
    upload_5 = Fabricate(:upload)
    upload_6 = Fabricate(:upload)

    Fabricate(:chat_upload, chat_message: chat_message_1, upload: upload_1)
    Fabricate(:chat_upload, chat_message: chat_message_2, upload: upload_2)
    Fabricate(:chat_upload, chat_message: chat_message_3, upload: upload_3)
    Fabricate(:chat_upload, chat_message: chat_message_4, upload: upload_4)
    Fabricate(:chat_upload, chat_message: chat_message_4, upload: upload_5)
    Fabricate(:chat_upload, chat_message: chat_message_4, upload: upload_6)

    # already existing reference, this migration is idempotent
    Fabricate(:chat_upload, chat_message: chat_message_2, upload: upload_6)
    Fabricate(:upload_reference, target: chat_message_2, upload: upload_6)

    expect { MoveChatUploadsToUploadReferences.new.up }.to change { UploadReference.count }.by(6)

    expect(UploadReference.exists?(target: chat_message_1, upload: upload_1)).to be_truthy
    expect(UploadReference.exists?(target: chat_message_2, upload: upload_2)).to be_truthy
    expect(UploadReference.exists?(target: chat_message_3, upload: upload_3)).to be_truthy
    expect(UploadReference.exists?(target: chat_message_4, upload: upload_4)).to be_truthy
    expect(UploadReference.exists?(target: chat_message_4, upload: upload_5)).to be_truthy
    expect(UploadReference.exists?(target: chat_message_4, upload: upload_6)).to be_truthy
  end
end
