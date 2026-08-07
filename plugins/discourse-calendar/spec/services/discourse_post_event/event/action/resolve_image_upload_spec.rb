# frozen_string_literal: true

RSpec.describe DiscoursePostEvent::Event::Action::ResolveImageUpload do
  subject(:resolved) { described_class.call(image:, post:) }

  fab!(:author, :user)
  fab!(:post) { Fabricate(:post, user: author) }

  let(:image) { nil }

  before do
    SiteSetting.calendar_enabled = true
    SiteSetting.discourse_post_event_enabled = true
  end

  context "when the image is blank" do
    it "returns nil" do
      expect(resolved).to be_nil
    end
  end

  context "with a short url" do
    fab!(:upload) { Fabricate(:upload, user: author) }

    let(:image) { upload.short_url }

    it "resolves the upload" do
      expect(resolved).to eq(upload)
    end

    it "returns nil when no upload matches the short url" do
      expect(described_class.call(image: "upload://nonexistent.png", post:)).to be_nil
    end
  end

  context "with a regular url" do
    fab!(:upload) { Fabricate(:upload, user: author) }

    let(:image) { upload.url }

    it "resolves the upload" do
      expect(resolved).to eq(upload)
    end
  end

  context "with a secure upload" do
    before do
      setup_s3
      SiteSetting.secure_uploads = true
    end

    it "returns nil when the upload is owned by another user" do
      other_user = Fabricate(:user)
      secure_upload = Fabricate(:secure_upload, user: other_user)

      expect(described_class.call(image: secure_upload.short_url, post:)).to be_nil
    end

    it "returns the upload when it is owned by the post author" do
      secure_upload = Fabricate(:secure_upload, user: author)

      expect(described_class.call(image: secure_upload.short_url, post:)).to eq(secure_upload)
    end

    it "returns the upload when the post author has a UserUpload link" do
      other_user = Fabricate(:user)
      secure_upload = Fabricate(:secure_upload, user: other_user)
      UserUpload.create!(upload: secure_upload, user: author)

      expect(described_class.call(image: secure_upload.short_url, post:)).to eq(secure_upload)
    end
  end

  context "with a non-secure upload owned by another user" do
    it "returns the upload" do
      other_user = Fabricate(:user)
      upload = Fabricate(:upload, user: other_user)

      expect(described_class.call(image: upload.short_url, post:)).to eq(upload)
    end
  end
end
