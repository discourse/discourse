# frozen_string_literal: true

RSpec.describe Acl::Target do
  subject(:target_acl) { described_class.new(flattened_acl_list) }

  fab!(:group)
  fab!(:user)

  let(:flattened_acl_list) do
    [
      { type: :group, id: group.id, permission: "view", target_type: "Category", target_id: 5 },
      { type: :group, id: group.id, permission: "edit", target_type: "Category", target_id: 5 },
      { type: "group", id: 22, permission: "view", target_type: "Category", target_id: 5 },
      { type: :user, id: user.id, permission: "manage", target_type: "Category", target_id: 5 },
      { type: "user", id: 99, permission: "view", target_type: "Category", target_id: 5 },
    ]
  end

  describe "#group_has_permission?" do
    it "returns true when the group id holds the permission" do
      expect(target_acl.group_has_permission?(group.id, "view")).to eq(true)
    end

    it "accepts a group record as well as an id" do
      expect(target_acl.group_has_permission?(group, "edit")).to eq(true)
    end

    it "returns false when the group does not hold the permission" do
      expect(target_acl.group_has_permission?(22, "edit")).to eq(false)
    end

    it "returns nil for a group not present in the list" do
      expect(target_acl.group_has_permission?(123_456, "view")).to be_nil
    end

    it "does not grant group permissions from non-group entries" do
      expect(target_acl.group_has_permission?(99, "manage")).to be_nil
    end
  end

  describe "#group_has_any_permission?" do
    it "returns true when the group holds any of the permissions" do
      expect(target_acl.group_has_any_permission?(group.id, %w[manage edit])).to eq(true)
    end

    it "returns false when the group holds none of the permissions" do
      expect(target_acl.group_has_any_permission?(22, %w[edit manage])).to eq(false)
    end

    it "returns false for a group not present in the list" do
      expect(target_acl.group_has_any_permission?(123_456, %w[view edit])).to eq(false)
    end
  end

  describe "#permission_group_ids" do
    it "returns all group ids holding the permission" do
      expect(target_acl.permission_group_ids("view")).to contain_exactly(group.id, 22)
    end

    it "returns only the matching groups for a more restrictive permission" do
      expect(target_acl.permission_group_ids("edit")).to contain_exactly(group.id)
    end

    it "returns an empty array when only non-group entries hold the permission" do
      expect(target_acl.permission_group_ids("manage")).to eq([])
    end

    it "returns an empty array for a permission that is not present" do
      expect(target_acl.permission_group_ids("own")).to eq([])
    end
  end

  describe "#group_ids_with_any_permission" do
    it "returns the unique group ids across all the permissions" do
      expect(target_acl.group_ids_with_any_permission(%w[view edit])).to contain_exactly(
        group.id,
        22,
      )
    end

    it "ignores permissions that are not present" do
      expect(target_acl.group_ids_with_any_permission(%w[view own])).to contain_exactly(
        group.id,
        22,
      )
    end
  end

  describe "#user_has_permission?" do
    it "returns true when the user id holds the permission" do
      expect(target_acl.user_has_permission?(user.id, "manage")).to eq(true)
    end

    it "accepts a user record as well as an id" do
      expect(target_acl.user_has_permission?(user, "manage")).to eq(true)
    end

    it "returns false when the user does not hold the permission" do
      expect(target_acl.user_has_permission?(99, "manage")).to eq(false)
    end

    it "returns nil for a user not present in the list" do
      expect(target_acl.user_has_permission?(123_456, "view")).to be_nil
    end

    it "does not grant user permissions from non-user entries" do
      expect(target_acl.user_has_permission?(group.id, "edit")).to be_nil
    end
  end

  describe "#user_has_any_permission?" do
    it "returns true when the user holds any of the permissions" do
      expect(target_acl.user_has_any_permission?(user.id, %w[view manage])).to eq(true)
    end

    it "returns false when the user holds none of the permissions" do
      expect(target_acl.user_has_any_permission?(99, %w[edit manage])).to eq(false)
    end

    it "returns false for a user not present in the list" do
      expect(target_acl.user_has_any_permission?(123_456, %w[view manage])).to eq(false)
    end
  end

  describe "#permission_user_ids" do
    it "returns all user ids holding the permission" do
      expect(target_acl.permission_user_ids("view")).to contain_exactly(99)
    end

    it "returns only the matching users for a more restrictive permission" do
      expect(target_acl.permission_user_ids("manage")).to contain_exactly(user.id)
    end

    it "returns an empty array when only non-user entries hold the permission" do
      expect(target_acl.permission_user_ids("edit")).to eq([])
    end

    it "returns an empty array for a permission that is not present" do
      expect(target_acl.permission_user_ids("own")).to eq([])
    end
  end

  describe "#user_ids_with_any_permission" do
    it "returns the unique user ids across all the permissions" do
      expect(target_acl.user_ids_with_any_permission(%w[view manage])).to contain_exactly(
        user.id,
        99,
      )
    end

    it "ignores permissions that are not present" do
      expect(target_acl.user_ids_with_any_permission(%w[view own])).to contain_exactly(99)
    end
  end
end
