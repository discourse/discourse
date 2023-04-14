# encoding: utf-8
# frozen_string_literal: true

RSpec.describe UserLookup do
  fab!(:user) { Fabricate(:user, username: "john_doe", name: "John Doe") }

  describe "#[]" do
    before { @user_lookup = UserLookup.new([user.id, nil]) }

    it "returns nil if user_id does not exists" do
      expect(@user_lookup[0]).to eq(nil)
    end

    it "returns nil if user_id is nil" do
      expect(@user_lookup[nil]).to eq(nil)
    end

    it "returns user if user_id exists" do
      user_lookup_user = @user_lookup[user.id]
      expect(user_lookup_user).to eq(user)
      expect(user_lookup_user.username).to eq("john_doe")
      expect(user_lookup_user.name).to eq("John Doe")
    end
  end

  describe "#primary_groups" do
    fab!(:group) { Fabricate(:group, name: "testgroup") }
    fab!(:user2) { Fabricate(:user, username: "jane_doe", name: "Jane Doe", primary_group: group) }

    before { @user_lookup = UserLookup.new([user.id, user2.id, nil]) }

    it "returns nil if user_id does not exists" do
      expect(@user_lookup.primary_groups[0]).to eq(nil)
    end

    it "returns nil if user_id is nil" do
      expect(@user_lookup.primary_groups[nil]).to eq(nil)
    end

    it "returns nil if user has no primary group" do
      expect(@user_lookup.primary_groups[user.id]).to eq(nil)
    end

    it "returns group if user has primary group" do
      user_lookup_group = @user_lookup.primary_groups[user2.id]
      expect(user_lookup_group).to eq(group)
      expect(user_lookup_group.name).to eq("testgroup")
    end
  end
end
