# frozen_string_literal: true

RSpec.describe Guardian do
  fab!(:user)
  fab!(:moderator)
  fab!(:post)
  fab!(:hidden_post_revision) { Fabricate(:post_revision, post:, number: 2, hidden: true) }

  describe "#can_view_post_version?" do
    it "denies non-staff from reconstructing a version through a hidden revision" do
      expect(Guardian.new(user).can_view_post_version?(post, 1)).to eq(true)
      expect(Guardian.new(user).can_view_post_version?(post, 2)).to eq(false)
    end

    it "allows staff to reconstruct a version through a hidden revision" do
      expect(Guardian.new(moderator).can_view_post_version?(post, 2)).to eq(true)
    end
  end

  describe "#can_navigate_unlisted_post_revisions?" do
    it "only allows staff" do
      expect(moderator.guardian.can_navigate_unlisted_post_revisions?).to eq(true)
      expect(user.guardian.can_navigate_unlisted_post_revisions?).to eq(false)
      expect(Guardian.new.can_navigate_unlisted_post_revisions?).to eq(false)
    end
  end

  describe "#can_unlist_post_revision?" do
    fab!(:post_revision) { Fabricate(:post_revision, post:, number: 3) }

    it "only allows staff" do
      expect(moderator.guardian.can_unlist_post_revision?(post_revision)).to eq(true)
      expect(user.guardian.can_unlist_post_revision?(post_revision)).to eq(false)
      expect(Guardian.new.can_unlist_post_revision?(post_revision)).to eq(false)
    end
  end

  describe "#can_relist_post_revision?" do
    fab!(:post_revision) { Fabricate(:post_revision, post:, number: 3, unlisted: true) }

    it "only allows staff" do
      expect(moderator.guardian.can_relist_post_revision?(post_revision)).to eq(true)
      expect(user.guardian.can_relist_post_revision?(post_revision)).to eq(false)
      expect(Guardian.new.can_relist_post_revision?(post_revision)).to eq(false)
    end
  end
end
