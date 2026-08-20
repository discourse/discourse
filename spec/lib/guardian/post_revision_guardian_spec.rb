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
end
