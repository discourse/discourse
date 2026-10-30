# frozen_string_literal: true

RSpec.describe Jobs::CleanUpBlogReviewUploads do
  fab!(:admin)
  fab!(:category)
  fab!(:drafts) { Fabricate(:private_category, group: Group[:staff]) }
  fab!(:topic) { Fabricate(:topic, category: drafts, user: admin) }
  fab!(:first_post) { Fabricate(:post, topic: topic, user: admin) }

  before { enable_blog!(category: category, drafts: drafts) }

  describe "#execute" do
    it "releases expired review uploads even when the plugin is disabled" do
      upload = Fabricate(:upload, user: admin, created_at: 3.days.ago)
      first_post.update!(
        raw: "![Review image](#{upload.short_url})",
        cooked: "<p><img src=\"#{upload.url}\"></p>",
      )
      first_post.link_post_uploads
      expired = Blog::Review.issue!(topic: topic, user: admin)
      active = Blog::Review.issue!(topic: topic, user: admin)
      expired.update!(expires_at: 1.second.ago)
      SiteSetting.blog_enabled = false

      described_class.new.execute(nil)

      expect(UploadReference.where(target: expired)).not_to exist
      expect(UploadReference.where(target: active).pluck(:upload_id)).to eq([upload.id])
      expect(UploadReference.where(target: first_post).pluck(:upload_id)).to eq([upload.id])

      active.update!(expires_at: 1.second.ago)
      first_post.update!(raw: "Image removed", cooked: "<p>Image removed</p>")
      first_post.link_post_uploads
      described_class.new.execute(nil)
      Jobs::CleanUpUploads.new.reset_last_cleanup!
      Jobs::CleanUpUploads.new.execute(nil)

      expect(Upload.where(id: upload.id)).not_to exist
      expect(Blog::Review.where(id: [expired.id, active.id]).count).to eq(2)
    end
  end
end
