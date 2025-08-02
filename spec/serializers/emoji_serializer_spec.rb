# frozen_string_literal: true

RSpec.describe EmojiSerializer do
  fab!(:custom_emoji) { CustomEmoji.create!(name: "trout", upload: Fabricate(:upload)) }

  describe "#url" do
    subject(:serializer) { described_class.new(emoji, root: false) }

    fab!(:emoji) { Emoji.load_custom.first }

    it "returns a valid URL" do
      expect(serializer.url).to start_with("/uploads/")
    end

    it "returns the creator's username" do
      expect(serializer.created_by).to eq(emoji.created_by)
    end

    it "works with a CDN" do
      set_cdn_url("https://cdn.com")
      expect(serializer.url).to start_with("https://cdn.com")
    end
  end

  describe "missing uploads" do
    before { custom_emoji.upload.destroy! }

    it "doesn't raise an error with a missing upload and a CDN" do
      emoji = Emoji.load_custom.first
      set_cdn_url("https://cdn.com")
      result = described_class.new(Emoji.load_custom.first, root: false).as_json
      expect(result[:url]).to be_blank
    end

    it "doesn't raise an error with a missing upload and an s3 CDN" do
      emoji = Emoji.load_custom.first

      SiteSetting.enable_s3_uploads = true
      SiteSetting.s3_upload_bucket = "s3bucket"
      SiteSetting.s3_access_key_id = "s3_access_key_id"
      SiteSetting.s3_secret_access_key = "s3_secret_access_key"
      SiteSetting.s3_cdn_url = "https://example.com"
      result = described_class.new(Emoji.load_custom.first, root: false).as_json

      expect(result[:url]).to be_blank
    end
  end
end
