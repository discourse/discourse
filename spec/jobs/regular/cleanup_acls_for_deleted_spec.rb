# frozen_string_literal: true

RSpec.describe Jobs::CleanupAclsForDeleted do
  describe "#execute" do
    fab!(:user)

    it "preserves ACL grants for an existing or restored user" do
      acl = Fabricate(:access_control_list_with_users, users: [user])

      described_class.new.execute(user_id: user.id)

      expect(acl.reload.allowed_user_ids).to eq([user.id])
    end

    it "still cleans deleted groups when the supplied user exists" do
      group = Fabricate(:group)
      acl = Fabricate(:access_control_list_with_users_and_groups, users: [user], groups: [group])
      group.destroy!

      described_class.new.execute(user_id: user.id, group_id: group.id)

      expect(acl.reload).to have_attributes(allowed_user_ids: [user.id], allowed_group_ids: [])
    end

    it "preserves transferred ownership when cleanup runs repeatedly" do
      admin = Fabricate(:admin)
      acl = Fabricate(:access_control_list_with_users, permission: "owner", users: [user])
      user.destroy!

      2.times { described_class.new.execute(user_id: user.id) }

      expect(acl.reload.allowed_user_ids).to eq([admin.id])
    end
  end

  context "when a group is deleted" do
    fab!(:group)
    fab!(:other_group, :group)
    fab!(:third_group, :group)
    fab!(:user)

    fab!(:access_control_list_1) do
      Fabricate(:access_control_list_with_groups, groups: [group, other_group])
    end
    fab!(:access_control_list_2) do
      Fabricate(:access_control_list_with_groups, groups: [other_group, third_group])
    end
    fab!(:access_control_list_3) { Fabricate(:access_control_list_with_groups, groups: [group]) }
    fab!(:access_control_list_4) do
      Fabricate(:access_control_list_with_users_and_groups, groups: [group], users: [user])
    end

    it "removes the group from associated access_control_list records when the group is destroyed" do
      group.destroy!
      described_class.new.execute(group_id: group.id)
      expect(access_control_list_1.reload.allowed_group_ids).to eq([other_group.id])
      expect(access_control_list_2.reload.allowed_group_ids).to eq([other_group.id, third_group.id])
    end

    it "destroys the ACL when the ACL record has no more allowed ids of users or groups" do
      acl_3_id = access_control_list_3.id
      acl_4_id = access_control_list_4.id
      group.destroy!
      described_class.new.execute(group_id: group.id)
      expect(AccessControlList.find_by(id: acl_3_id)).to eq(nil)
      expect(AccessControlList.find_by(id: acl_4_id)).not_to eq(nil)
    end
  end

  context "when a user is deleted" do
    fab!(:user)
    fab!(:other_user, :user)
    fab!(:third_user, :user)
    fab!(:group)

    fab!(:access_control_list_1) do
      Fabricate(:access_control_list_with_users, users: [user, other_user])
    end
    fab!(:access_control_list_2) do
      Fabricate(:access_control_list_with_users, users: [other_user, third_user])
    end
    fab!(:access_control_list_3) { Fabricate(:access_control_list_with_users, users: [user]) }
    fab!(:access_control_list_4) do
      Fabricate(:access_control_list_with_users_and_groups, users: [user], groups: [group])
    end

    it "removes the user from associated access_control_list records when the user is destroyed" do
      user.destroy!
      described_class.new.execute(user_id: user.id)

      expect(access_control_list_1.reload.allowed_user_ids).to eq([other_user.id])
      expect(access_control_list_2.reload.allowed_user_ids).to eq([other_user.id, third_user.id])
    end

    it "destroys the ACL when the ACL record has no more allowed ids of users or groups" do
      acl_3_id = access_control_list_3.id
      acl_4_id = access_control_list_4.id

      user.destroy!
      described_class.new.execute(user_id: user.id)

      expect(AccessControlList.find_by(id: acl_3_id)).to eq(nil)
      expect(AccessControlList.find_by(id: acl_4_id)).not_to eq(nil)
    end
  end
end
