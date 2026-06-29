# frozen_string_literal: true

RSpec.describe AccessControlListManager do
  class AclTargetSpecTarget < Category
    include AclTarget

    self.table_name = "categories"

    def self.name
      "AclTargetSpecTarget"
    end
  end

  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:target) }
    it { is_expected.to validate_presence_of(:owner) }
    it { is_expected.to validate_length_of(:owner).is_at_most(100) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:admin)
    fab!(:group)
    fab!(:other_group, :group)
    fab!(:target) do
      cat = AclTargetSpecTarget.new(name: "Test Category", user: admin)
      cat.skip_publish = true
      cat.save!
      cat
    end

    let(:params) { { target:, flattened_acl:, owner: } }
    let(:dependencies) { { guardian: } }
    let(:guardian) { admin.guardian }
    let(:owner) { "test_owner" }

    let(:flattened_acl) do
      [
        { type: "group", id: group.id, permission: "view" },
        { type: "group", id: other_group.id, permission: "edit" },
      ]
    end

    context "when the contract is invalid" do
      let(:owner) { "" }

      it { is_expected.to fail_a_contract }
    end

    context "when no ACLs are provided" do
      let(:flattened_acl) { [] }

      it { is_expected.to fail_a_policy(:has_at_least_one_acl) }
    end

    context "when everything is ok" do
      it { is_expected.to run_successfully }

      it "creates one access control list per permission for the target" do
        expect { result }.to change { AccessControlList.where(target: target).count }.from(0).to(2)

        view_acl = AccessControlList.find_by(target: target, permission: "view")
        edit_acl = AccessControlList.find_by(target: target, permission: "edit")
        expect(view_acl.allowed_group_ids).to contain_exactly(group.id)
        expect(edit_acl.allowed_group_ids).to contain_exactly(other_group.id)
      end

      it "stamps the records with the given owner" do
        result

        expect(AccessControlList.where(target: target).pluck(:owner).uniq).to eq(["test_owner"])
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
  end
end
