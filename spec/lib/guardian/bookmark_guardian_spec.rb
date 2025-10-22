# frozen_string_literal: true

RSpec.describe BookmarkGuardian do
  fab!(:user)
  fab!(:moderator)
  fab!(:bookmark) { Fabricate(:bookmark, user:) }

  describe "#can_delete_bookmark?" do
    it "returns true when user owns the bookmark" do
      expect(Guardian.new(user).can_delete_bookmark?(bookmark)).to eq(true)
    end

    it "returns false when user doesn't own the bookmark" do
      expect(Guardian.new(moderator).can_delete_bookmark?(bookmark)).to eq(false)
    end
  end

  describe "#can_edit_bookmark?" do
    it "returns true when user owns the bookmark" do
      expect(Guardian.new(user).can_delete_bookmark?(bookmark)).to eq(true)
    end

    it "returns false when user doesn't own the bookmark" do
      expect(Guardian.new(moderator).can_delete_bookmark?(bookmark)).to eq(false)
    end
  end
end
