# frozen_string_literal: true

RSpec.describe AccessControlList::Action::BuildReplacement do
  subject(:replacement) do
    described_class.call(acl_entries:, initial_owner:, owner_user_ids:, target:, current_acl:)
  end

  class BuildReplacementAclTargetSpecTarget < Category
    include AclTarget

    self.table_name = "categories"

    def self.name
      "BuildReplacementAclTargetSpecTarget"
    end

    ACL_PERMISSIONS = Acl::Permissions.new(:view, :edit, :manage)
  end

  fab!(:initial_owner, :user)
  fab!(:current_owner, :user)
  fab!(:co_owner, :user)
  fab!(:group)
  fab!(:target) { Fabricate(:category).becomes(BuildReplacementAclTargetSpecTarget) }

  let(:acl_entries) { [{ type: :group, id: group.id, permission: "view" }] }
  let(:owner_user_ids) { nil }
  let(:current_acl) { AccessControlList.where(target:).target_acl(target) }

  context "when the target has no current owner" do
    it "adds the initial owner and reports the resulting changes" do
      expect(replacement.flattened_acl).to contain_exactly(
        { type: :group, id: group.id, permission: "view" },
        { type: :user, id: initial_owner.id, permission: Acl::Permissions::OWNER },
      )
      expect(replacement.added_owner_user_ids).to eq([initial_owner.id])
      expect(replacement.removed_owner_user_ids).to be_empty
      expect(replacement.ordinary_permissions_changed).to be(true)
    end
  end

  context "when requested owners are provided for an ownerless target" do
    let(:owner_user_ids) { [co_owner.id, co_owner.id] }

    it "deduplicates the request and retains the initial owner" do
      expect(replacement.permissions.dig(Acl::Permissions::OWNER, :user_ids)).to contain_exactly(
        co_owner.id,
        initial_owner.id,
      )
      expect(replacement.added_owner_user_ids).to contain_exactly(co_owner.id, initial_owner.id)
    end
  end

  context "when the current owners are not replaced" do
    fab!(:owner_acl) do
      Fabricate(
        :access_control_list_with_users,
        target:,
        permission: Acl::Permissions::OWNER,
        users: [current_owner],
      )
    end

    it "preserves the current owners" do
      expect(replacement.permissions.dig(Acl::Permissions::OWNER, :user_ids)).to eq(
        [current_owner.id],
      )
      expect(replacement.added_owner_user_ids).to be_empty
      expect(replacement.removed_owner_user_ids).to be_empty
    end
  end

  context "when the current owner set is replaced" do
    fab!(:owner_acl) do
      Fabricate(
        :access_control_list_with_users,
        target:,
        permission: Acl::Permissions::OWNER,
        users: [current_owner],
      )
    end

    let(:owner_user_ids) { [co_owner.id] }

    it "reports owners added and removed" do
      expect(replacement.added_owner_user_ids).to eq([co_owner.id])
      expect(replacement.removed_owner_user_ids).to eq([current_owner.id])
    end
  end

  context "when an owner also has a lower direct permission" do
    fab!(:owner_acl) do
      Fabricate(
        :access_control_list_with_users,
        target:,
        permission: Acl::Permissions::OWNER,
        users: [current_owner],
      )
    end

    let(:acl_entries) do
      [
        { type: :user, id: current_owner.id, permission: "manage" },
        { type: :group, id: group.id, permission: "manage" },
      ]
    end

    it "removes the redundant user permission and preserves the group permission" do
      expect(replacement.flattened_acl).to contain_exactly(
        { type: :group, id: group.id, permission: "manage" },
        { type: :user, id: current_owner.id, permission: Acl::Permissions::OWNER },
      )
    end
  end

  context "when the target declares a missing mandatory permission" do
    before do
      BuildReplacementAclTargetSpecTarget.stubs(:mandatory_acl).returns(
        [{ type: :group, id: Group::AUTO_GROUPS[:admins], permission: "manage" }],
      )
    end

    it "injects the mandatory entry" do
      expect(replacement.flattened_acl).to include(
        type: :group,
        id: Group::AUTO_GROUPS[:admins],
        permission: "manage",
      )
    end
  end

  context "when only ownership changes" do
    fab!(:owner_acl) do
      Fabricate(
        :access_control_list_with_users,
        target:,
        permission: Acl::Permissions::OWNER,
        users: [current_owner],
      )
    end
    fab!(:view_acl) do
      Fabricate(:access_control_list_with_groups, target:, permission: "view", groups: [group])
    end

    let(:owner_user_ids) { [current_owner.id, co_owner.id] }

    it "does not report an ordinary permission change" do
      expect(replacement.ordinary_permissions_changed).to be(false)
    end
  end
end
