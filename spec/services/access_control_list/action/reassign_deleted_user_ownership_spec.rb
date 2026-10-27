# frozen_string_literal: true

RSpec.describe AccessControlList::Action::ReassignDeletedUserOwnership do
  describe ".call" do
    subject(:reassign_ownership) do
      described_class.call(
        owner_acl:,
        deleted_user_id: user.id,
        deleted_username: user.username,
        deleted_at:,
        new_admin_owner:,
      )
    end

    fab!(:user)
    fab!(:new_admin_owner, :admin)
    fab!(:owner_acl) do
      Fabricate(:access_control_list_with_users, permission: "owner", users: [user])
    end

    let(:deleted_at) { Time.zone.parse("2026-10-26T01:23:45Z") }

    it "removes redundant grants for the new owner while preserving other users and groups" do
      group = Fabricate(:group)
      other_user = Fabricate(:user)
      view_acl =
        Fabricate(
          :access_control_list_with_users_and_groups,
          target: owner_acl.target,
          permission: "view",
          users: [new_admin_owner, other_user],
          groups: [group],
        )
      manage_acl =
        Fabricate(
          :access_control_list_with_users,
          target: owner_acl.target,
          permission: "manage",
          users: [new_admin_owner],
        )

      reassign_ownership

      expect(view_acl.reload).to have_attributes(
        allowed_user_ids: [other_user.id],
        allowed_group_ids: [group.id],
      )
      expect(AccessControlList.exists?(manage_acl.id)).to eq(false)
    end

    it "transfers ownership for a target type whose class is unavailable" do
      owner_acl.update_columns(target_type: "UnavailableAclTarget")

      reassign_ownership

      expect(owner_acl.reload.allowed_user_ids).to eq([new_admin_owner.id])
      expect(UserHistory.last.subject).to eq("UnavailableAclTarget (#{owner_acl.target_id})")
    end

    it "leaves records unchanged when the user has already lost ownership" do
      owner_acl.update!(allowed_user_ids: [new_admin_owner.id])

      expect { reassign_ownership }.not_to change(UserHistory, :count)
      expect(owner_acl.reload.allowed_user_ids).to eq([new_admin_owner.id])
    end
  end
end
