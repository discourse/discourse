# frozen_string_literal: true

RSpec.describe IgnoredUser do
  describe ".ignored_ids_for" do
    fab!(:user)
    fab!(:target, :user)
    fab!(:admin) { Fabricate(:user, admin: true) }

    before { Fabricate(:ignored_user, user: user, ignored_user: target) }

    it "returns ids of users ignored by the given user" do
      expect(described_class.ignored_ids_for(user)).to contain_exactly(target.id)
    end

    it "excludes staff even if ignored" do
      Fabricate(:ignored_user, user: user, ignored_user: admin)
      expect(described_class.ignored_ids_for(user)).not_to include(admin.id)
    end

    it "returns an empty array when user is nil" do
      expect(described_class.ignored_ids_for(nil)).to eq([])
    end
  end
end
