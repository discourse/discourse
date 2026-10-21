# frozen_string_literal: true

RSpec.describe AccessControlListManager do
  class AclTargetSpecTarget < Category
    include AclTarget

    self.table_name = "categories"

    def self.name
      "AclTargetSpecTarget"
    end

    ACL_PERMISSIONS = Acl::Permissions.new(:view, :edit, :manage)
  end

  class InheritedAclTargetSpecTarget < AclTargetSpecTarget
  end

  class UndeclaredAclTargetSpecTarget < Category
    include AclTarget
  end

  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:target) }
    it { is_expected.to validate_presence_of(:source) }
    it { is_expected.to validate_length_of(:source).is_at_most(100) }
    it { is_expected.to validate_presence_of(:owner_user_id) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:admin)
    fab!(:target_owner, :user)
    fab!(:group)
    fab!(:other_group, :group)
    fab!(:target) do
      cat = AclTargetSpecTarget.new(name: "Test Category", user: admin)
      cat.skip_publish = true
      cat.save!
      cat
    end

    let(:params) { { target:, flattened_acl:, source:, owner_user_id: } }
    let(:dependencies) { { guardian: } }
    let(:guardian) { admin.guardian }
    let(:source) { "test_source" }
    let(:owner_user_id) { admin.id }

    let(:flattened_acl) do
      [
        { type: "group", id: group.id, permission: "view" },
        { type: "group", id: other_group.id, permission: "edit" },
      ]
    end

    context "when owner_user_id is missing" do
      fab!(:existing_acl) do
        Fabricate(:access_control_list_with_groups, target:, permission: "manage", groups: [group])
      end

      let(:owner_user_id) { nil }

      it "fails the contract without changing ACLs" do
        expect { result }.not_to change { AccessControlList.where(target:).map(&:attributes) }
        expect(result).to fail_a_contract
      end
    end

    context "when owner_user_id does not identify a user" do
      fab!(:existing_acl) do
        Fabricate(:access_control_list_with_groups, target:, permission: "manage", groups: [group])
      end

      let(:owner_user_id) { 0 }

      it "fails to find the owner without changing ACLs" do
        expect { result }.not_to change { AccessControlList.where(target:).map(&:attributes) }
        expect(result).to fail_to_find_a_model(:owner_user)
      end
    end

    context "when only an owner is provided for a new target" do
      let(:flattened_acl) { [] }

      it "persists the authoritative owner" do
        expect(result).to run_successfully
        expect(AccessControlList.where(target:).flattened_list).to contain_exactly(
          include(type: :user, id: owner_user_id, permission: "owner", mandatory: true),
        )
      end
    end

    context "when the target has no permission declaration" do
      fab!(:target) { Fabricate(:category).becomes(UndeclaredAclTargetSpecTarget) }

      it "raises a configuration error without creating ACLs" do
        expect { result }.to raise_error(NameError, /ACL_PERMISSIONS/)
        expect(AccessControlList.where(target:)).to be_empty
      end
    end

    context "when the target inherits its permission declaration" do
      fab!(:target) { Fabricate(:category).becomes(InheritedAclTargetSpecTarget) }

      it "accepts and persists inherited permissions" do
        expect(result).to run_successfully
        expect(AccessControlList.where(target:).pluck(:permission)).to contain_exactly(
          "view",
          "edit",
          "owner",
        )
      end
    end

    context "when an unknown permission is provided" do
      let(:flattened_acl) { [{ type: "group", id: group.id, permission: "Jester" }] }

      it "rejects the ACL without creating permissions or logging a change" do
        expect { result }.not_to change { AccessControlList.where(target:).count }
        expect(result).to fail_a_policy(:has_valid_permissions)
        expect(
          UserHistory.where(action: UserHistory.actions[:change_access_control_list_permissions]),
        ).to be_empty
      end
    end

    context "when valid and invalid permissions are mixed" do
      fab!(:existing_acl) do
        Fabricate(:access_control_list_with_groups, target:, permission: "manage", groups: [group])
      end

      let(:flattened_acl) do
        [
          { type: "group", id: group.id, permission: "view" },
          { type: "group", id: other_group.id, permission: "Jester" },
        ]
      end

      it "preserves all existing ACL data" do
        expect { result }.not_to change { AccessControlList.where(target:).map(&:attributes) }
        expect(result).to fail_a_policy(:has_valid_permissions)
      end
    end

    context "when a permission is blank" do
      let(:flattened_acl) { [{ type: "group", id: group.id, permission: "" }] }

      it { is_expected.to fail_a_policy(:has_valid_permissions) }
    end

    context "when a permission is missing" do
      let(:flattened_acl) { [{ type: "group", id: group.id }] }

      it { is_expected.to fail_a_policy(:has_valid_permissions) }
    end

    context "when a mandatory permission is invalid" do
      before do
        AclTargetSpecTarget.stubs(:mandatory_acl).returns(
          [{ type: :group, id: Group::AUTO_GROUPS[:admins], permission: "Jester" }],
        )
      end

      it "rejects the injected permission without creating ACLs" do
        expect { result }.not_to change { AccessControlList.where(target:).count }
        expect(result).to fail_a_policy(:has_valid_permissions)
      end
    end

    context "when everything is ok" do
      it { is_expected.to run_successfully }

      it "creates one access control list per permission for the target" do
        expect { result }.to change { AccessControlList.where(target: target).count }.from(0).to(3)

        view_acl = AccessControlList.find_by(target: target, permission: "view")
        edit_acl = AccessControlList.find_by(target: target, permission: "edit")
        expect(view_acl.allowed_group_ids).to contain_exactly(group.id)
        expect(edit_acl.allowed_group_ids).to contain_exactly(other_group.id)
        expect(AccessControlList.find_by(target:, permission: "owner").allowed_user_ids).to(
          contain_exactly(owner_user_id),
        )
      end

      it "stamps the records with the given source" do
        result

        expect(AccessControlList.where(target: target).pluck(:source).uniq).to eq(["test_source"])
      end

      it "logs the permission change as a staff action" do
        expect { result }.to change {
          UserHistory.where(
            action: UserHistory.actions[:change_access_control_list_permissions],
          ).count
        }.by(1)

        log = UserHistory.last
        expect(log.subject).to eq("Category (#{target.id})")
        expect(log.new_value).to include("view", "edit")
        expect(log.previous_value).to eq("")
      end
    end

    context "when permissions already exist for the target" do
      fab!(:existing_acl) do
        Fabricate(
          :access_control_list_with_groups,
          target: target,
          permission: "manage",
          groups: [group],
        )
      end

      it "replaces the previous access control lists" do
        existing_id = existing_acl.id
        result

        expect(AccessControlList.where(target: target).pluck(:permission)).to contain_exactly(
          "view",
          "edit",
          "owner",
        )
        expect(AccessControlList.find_by(id: existing_id)).to be_nil
      end

      it "records the previous permissions in the staff action log" do
        result

        log = UserHistory.last
        expect(log.subject).to eq("Category (#{target.id})")
        expect(log.new_value).to include("view", "edit")
        expect(log.previous_value).to include("manage")
      end
    end

    describe "mandatory ACL" do
      context "when the target does not have mandatory ACLs" do
        it "does not modify the flattened ACL" do
          result

          expect(AccessControlList.where(target: target).pluck(:permission)).to contain_exactly(
            "edit",
            "owner",
            "view",
          )
        end
      end

      context "when the target has mandatory ACLs" do
        before do
          AclTargetSpecTarget.stubs(:mandatory_acl).returns(
            [{ type: :group, id: Group::AUTO_GROUPS[:admins], permission: "manage" }],
          )
        end

        it "injects the mandatory ACL into the list of ACLs to be created" do
          result

          expect(AccessControlList.where(target: target).pluck(:permission)).to contain_exactly(
            "view",
            "edit",
            "manage",
            "owner",
          )

          manage_acl = AccessControlList.find_by(target: target, permission: "manage")
          expect(manage_acl.allowed_group_ids).to contain_exactly(Group::AUTO_GROUPS[:admins])
        end

        context "when the mandatory ACL is already included in the flattened ACL" do
          let(:flattened_acl) do
            [
              { type: "group", id: group.id, permission: "view" },
              { type: "group", id: other_group.id, permission: "edit" },
              { type: "group", id: Group::AUTO_GROUPS[:admins], permission: "manage" },
            ]
          end

          it "does not create duplicate ACLs" do
            result

            expect(AccessControlList.where(target: target, permission: "manage").count).to eq(1)
          end
        end
      end
    end

    describe "banned ACL" do
      let(:flattened_acl) do
        [
          { type: "group", id: group.id, permission: "view" },
          { type: "group", id: other_group.id, permission: "edit" },
          { type: "group", id: Group::AUTO_GROUPS[:anonymous_users], permission: "edit" },
        ]
      end

      context "when the target does not have banned ACLs" do
        it "does not modify the flattened ACL" do
          result

          expect(AccessControlList.where(target: target).pluck(:permission)).to contain_exactly(
            "edit",
            "owner",
            "view",
          )
        end
      end

      context "when the target has banned ACLs" do
        before do
          AclTargetSpecTarget.stubs(:banned_acl).returns(
            [{ type: :group, id: Group::AUTO_GROUPS[:anonymous_users], permission: "edit" }],
          )
        end

        it { is_expected.to fail_a_policy(:has_no_banned_acl) }
      end
    end

    describe "owner ACL" do
      fab!(:existing_owner_acl) do
        Fabricate(
          :access_control_list_with_users,
          target:,
          permission: "owner",
          users: [target_owner],
        )
      end

      it "preserves an existing owner when the submitted ACL omits it" do
        expect(result).to run_successfully

        owner_acl = AccessControlList.find_by(target:, permission: "owner")
        expect(owner_acl.allowed_user_ids).to contain_exactly(target_owner.id)
      end

      it "rejects a submitted user who is not an existing owner" do
        flattened_acl << { type: "user", id: owner_user_id, permission: "owner" }

        expect(result).to fail_a_policy(:has_valid_owner_entries)
        expect(existing_owner_acl.reload.allowed_user_ids).to contain_exactly(target_owner.id)
      end

      it "rejects a group owner" do
        flattened_acl << { type: "group", id: group.id, permission: "owner" }

        expect(result).to fail_a_policy(:has_valid_owner_entries)
        expect(existing_owner_acl.reload.allowed_user_ids).to contain_exactly(target_owner.id)
      end

      it "removes owners from lower direct user grants" do
        flattened_acl << { type: "user", id: target_owner.id, permission: "manage" }

        expect(result).to run_successfully
        expect(AccessControlList.find_by(target:, permission: "manage")).to be_nil
        expect(AccessControlList.find_by(target:, permission: "owner").allowed_user_ids).to(
          contain_exactly(target_owner.id),
        )
      end
    end
  end
end
