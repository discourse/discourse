# frozen_string_literal: true

RSpec.describe AccessControlList::Apply do
  class ApplyAclTargetSpecTarget < Category
    include AclTarget

    self.table_name = "categories"

    def self.name
      "ApplyAclTargetSpecTarget"
    end

    ACL_PERMISSIONS = Acl::Permissions.new(:view, :edit, :manage)
  end

  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:acl_target_type) }
    it { is_expected.to allow_value(1).for(:acl_target_id) }
    it { is_expected.not_to allow_value(0).for(:acl_target_id) }
    it { is_expected.to validate_presence_of(:source) }
    it { is_expected.to validate_length_of(:source).is_at_most(100) }
    it { is_expected.to allow_value([Discourse::SYSTEM_USER_ID]).for(:owner_user_ids) }
    it { is_expected.not_to allow_value([0]).for(:owner_user_ids) }
    it { is_expected.not_to allow_value([-2]).for(:owner_user_ids) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:admin)
    fab!(:target_owner, :user)
    fab!(:co_owner, :user)
    fab!(:other_user, :user)
    fab!(:group)
    fab!(:other_group, :group)
    fab!(:target) { Fabricate(:category).becomes(ApplyAclTargetSpecTarget) }

    let(:params) do
      {
        acl_target_type: target.class.name,
        acl_target_id: target.id,
        acl_entries:,
        source: "test_source",
        initial_owner_user_id: target_owner.id,
        owner_user_ids:,
      }
    end
    let(:dependencies) { { guardian: admin.guardian } }
    let(:acl_entries) do
      [
        { type: :group, id: group.id, permission: "view" },
        { type: :group, id: other_group.id, permission: "edit" },
      ]
    end
    let(:owner_user_ids) { nil }

    context "when the contract is invalid" do
      let(:params) { super().merge(acl_target_id: 0) }

      it { is_expected.to fail_a_contract }
    end

    context "when the ACL target is not found" do
      let(:params) { super().merge(acl_target_id: 999_999) }

      it { is_expected.to fail_to_find_a_model(:acl_target) }
    end

    context "when an owner is submitted as an ordinary ACL entry" do
      let(:acl_entries) do
        [{ type: :user, id: target_owner.id, permission: Acl::Permissions::OWNER }]
      end

      it { is_expected.to fail_a_policy(:has_no_owner_entries) }
    end

    context "when an ordinary ACL grantee does not exist" do
      let(:acl_entries) { [{ type: :user, id: 999_999, permission: "view" }] }

      it { is_expected.to fail_a_policy(:grantees_exist) }
    end

    context "when a requested owner does not exist" do
      let(:owner_user_ids) { [co_owner.id, 999_999] }

      it { is_expected.to fail_a_policy(:requested_owners_exist) }
    end

    context "when the system user is the current and requested owner" do
      fab!(:owner_acl) do
        Fabricate(
          :access_control_list_with_users,
          target:,
          permission: Acl::Permissions::OWNER,
          users: [Discourse.system_user],
        )
      end

      let(:acl_entries) { [] }
      let(:owner_user_ids) { [Discourse::SYSTEM_USER_ID] }

      it "preserves the system user as the owner" do
        expect(result).to run_successfully
        expect(
          AccessControlList.find_by!(target:, permission: Acl::Permissions::OWNER).allowed_user_ids,
        ).to eq([Discourse::SYSTEM_USER_ID])
      end
    end

    context "without an initial owner for an ownerless target" do
      let(:params) { super().merge(initial_owner_user_id: 999_999) }

      it { is_expected.to fail_a_policy(:has_initial_owner) }
    end

    context "when a non-owner requests an ownership change" do
      fab!(:owner_acl) do
        Fabricate(
          :access_control_list_with_users,
          target:,
          permission: Acl::Permissions::OWNER,
          users: [target_owner],
        )
      end

      let(:dependencies) { { guardian: other_user.guardian } }
      let(:owner_user_ids) { [target_owner.id, co_owner.id] }

      it { is_expected.to fail_a_policy(:can_change_owners) }
    end

    context "when an owner removes the final owner" do
      fab!(:owner_acl) do
        Fabricate(
          :access_control_list_with_users,
          target:,
          permission: Acl::Permissions::OWNER,
          users: [target_owner],
        )
      end

      let(:dependencies) { { guardian: target_owner.guardian } }
      let(:owner_user_ids) { [] }

      it { is_expected.to fail_a_policy(:has_at_least_one_owner) }
    end

    context "when an unknown permission is requested" do
      let(:acl_entries) { [{ type: :group, id: group.id, permission: "unknown" }] }

      it { is_expected.to fail_a_policy(:has_valid_permissions) }
    end

    context "when a banned ACL entry is requested" do
      let(:acl_entries) { [{ type: :group, id: group.id, permission: "edit" }] }

      before do
        ApplyAclTargetSpecTarget.stubs(:banned_acl).returns(
          [{ type: :group, id: group.id, permission: "edit" }],
        )
      end

      it { is_expected.to fail_a_policy(:has_no_banned_acl) }
    end

    context "when applying an initial ACL" do
      it { is_expected.to run_successfully }

      it "persists the owner and ordinary permissions with the source" do
        expect { result }.to change { AccessControlList.where(target:).count }.from(0).to(3)

        expect(AccessControlList.where(target:).pluck(:source).uniq).to eq(["test_source"])
        expect(AccessControlList.find_by!(target:, permission: "view").allowed_group_ids).to eq(
          [group.id],
        )
        expect(AccessControlList.find_by!(target:, permission: "edit").allowed_group_ids).to eq(
          [other_group.id],
        )
        expect(
          AccessControlList.find_by!(target:, permission: Acl::Permissions::OWNER).allowed_user_ids,
        ).to eq([target_owner.id])
      end

      it "logs the ordinary permission and owner changes" do
        expect { result }.to change {
          UserHistory.where(
            action: UserHistory.actions[:change_access_control_list_permissions],
          ).count
        }.by(1).and change {
                UserHistory.where(action: UserHistory.actions[:add_access_control_list_owner]).count
              }.by(1)
      end
    end

    context "when a deleted owner is submitted after their ownership was transferred" do
      fab!(:owner_acl) do
        Fabricate(
          :access_control_list_with_users,
          target:,
          permission: Acl::Permissions::OWNER,
          users: [target_owner],
        )
      end

      let(:owner_user_ids) { [target_owner.id] }

      before { target_owner.destroy! }

      it "rejects the stale owner and preserves the replacement admin" do
        expect(result).to fail_a_policy(:requested_owners_exist)
        expect(owner_acl.reload.allowed_user_ids).to eq([admin.id])
      end
    end

    context "when an admin specifies owners for an ownerless target" do
      let(:acl_entries) { [] }
      let(:owner_user_ids) { [co_owner.id] }

      it "retains the initial owner and adds every requested owner" do
        expect(result).to run_successfully
        expect(
          AccessControlList.find_by!(target:, permission: Acl::Permissions::OWNER).allowed_user_ids,
        ).to contain_exactly(target_owner.id, co_owner.id)
      end
    end

    context "when existing owners are omitted from the request" do
      fab!(:owner_acl) do
        Fabricate(
          :access_control_list_with_users,
          target:,
          permission: Acl::Permissions::OWNER,
          users: [target_owner],
        )
      end

      it "preserves the current owners" do
        expect(result).to run_successfully
        expect(
          AccessControlList.find_by!(target:, permission: Acl::Permissions::OWNER).allowed_user_ids,
        ).to eq([target_owner.id])
      end
    end

    context "when a current owner replaces the owner set" do
      fab!(:owner_acl) do
        Fabricate(
          :access_control_list_with_users,
          target:,
          permission: Acl::Permissions::OWNER,
          users: [target_owner, co_owner],
        )
      end

      let(:dependencies) { { guardian: target_owner.guardian } }
      let(:acl_entries) { [] }
      let(:owner_user_ids) { [co_owner.id] }

      it "allows self-removal while another owner remains" do
        expect(result).to run_successfully
        expect(
          AccessControlList.find_by!(target:, permission: Acl::Permissions::OWNER).allowed_user_ids,
        ).to eq([co_owner.id])
      end

      it "logs the ownership removal without an ordinary permission change" do
        expect { result }.to change {
          UserHistory.where(action: UserHistory.actions[:remove_access_control_list_owner]).count
        }.by(1).and not_change {
                UserHistory.where(
                  action: UserHistory.actions[:change_access_control_list_permissions],
                ).count
              }

        expect(UserHistory.last).to have_attributes(
          subject: "Category (#{target.id})",
          target_user_id: target_owner.id,
        )
      end
    end
  end
end
