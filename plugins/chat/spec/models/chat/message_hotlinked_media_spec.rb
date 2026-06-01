# frozen_string_literal: true

RSpec.describe Chat::MessageHotlinkedMedia do
  fab!(:chat_message)
  fab!(:upload)

  it "associates with a chat message and an upload" do
    record =
      described_class.create!(
        chat_message: chat_message,
        url: "https://example.com/cat.jpg",
        status: :downloaded,
        upload: upload,
      )

    expect(record.reload.chat_message).to eq(chat_message)
    expect(record.upload).to eq(upload)
    expect(chat_message.hotlinked_media).to include(record)
  end

  it "allows a nil upload for failed attempts" do
    record =
      described_class.create!(
        chat_message: chat_message,
        url: "https://example.com/broken.jpg",
        status: :download_failed,
      )

    expect(record.reload.upload).to be_nil
    expect(record).to be_download_failed
  end

  describe ".normalize_src" do
    it "strips the scheme by default" do
      expect(described_class.normalize_src("http://Example.COM/Cat.jpg")).to eq(
        "//example.com/Cat.jpg",
      )
    end

    it "preserves the scheme when reset_scheme: false" do
      expect(
        described_class.normalize_src("http://example.com/cat.jpg", reset_scheme: false),
      ).to eq("http://example.com/cat.jpg")
    end
  end
end
