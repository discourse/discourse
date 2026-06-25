# frozen_string_literal: true

RSpec.describe Jobs::CleanupAclsForDeleted do
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
end
