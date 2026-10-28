# frozen_string_literal: true

RSpec.describe Blog::Review do
  fab!(:admin)
  fab!(:category)
  fab!(:drafts) { Fabricate(:private_category, group: Group[:staff]) }
  fab!(:topic) { Fabricate(:topic, category: drafts, user: admin) }
  fab!(:first_post) { Fabricate(:post, topic: topic, user: admin) }

  let(:upload) { Fabricate(:upload, user: admin, created_at: 3.days.ago) }

  before do
    enable_blog!(category: category, drafts: drafts)
    first_post.update!(
      raw: "![Review image](#{upload.short_url})",
      cooked: "<p><img src=\"#{upload.url}\"></p>",
    )
    first_post.link_post_uploads
  end

  describe ".issue!" do
    it "retains snapshot uploads after the working draft removes them" do
      review = described_class.issue!(topic: topic, user: admin)
      first_post.update!(raw: "Image removed", cooked: "<p>Image removed</p>")
      first_post.link_post_uploads

      Jobs::CleanUpUploads.new.reset_last_cleanup!
      Jobs::CleanUpUploads.new.execute(nil)

      expect(review.reload).to be_accessible
      expect(review.cooked).to include(upload.url)
      expect(Upload.where(id: upload.id)).to exist
      expect(UploadReference.where(target: review).pluck(:upload_id)).to eq([upload.id])
    end
  end

  describe "#revoke!" do
    it "releases snapshot references without removing the draft's references" do
      review = described_class.issue!(topic: topic, user: admin)
      expect(UploadReference.where(target: review)).to exist

      review.revoke!(admin)

      expect(UploadReference.where(target: review)).not_to exist
      expect(UploadReference.where(target: first_post).pluck(:upload_id)).to eq([upload.id])
    end
  end

  describe ".revoke_for_topic!" do
    it "releases references for every revoked snapshot" do
      reviews = 2.times.map { described_class.issue!(topic: topic, user: admin) }
      expect(UploadReference.where(target: reviews).count).to eq(2)

      described_class.revoke_for_topic!(topic.id)

      expect(described_class.where(id: reviews).where(revoked_at: nil)).not_to exist
      expect(UploadReference.where(target: reviews)).not_to exist
      expect(UploadReference.where(target: first_post).pluck(:upload_id)).to eq([upload.id])
    end
  end

  describe "#destroy!" do
    it "releases references when the snapshot is deleted" do
      review = described_class.issue!(topic: topic, user: admin)
      expect(UploadReference.where(target: review)).to exist

      review.destroy!

      expect(UploadReference.where(target: review)).not_to exist
    end
  end
end
