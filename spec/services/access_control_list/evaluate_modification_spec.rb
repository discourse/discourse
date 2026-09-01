# frozen_string_literal: true

RSpec.describe AccessControlList::EvaluateModification do
  describe described_class::Contract, type: :model do
    it { is_expected.to allow_values(nil, 1).for(:target_id) }
    it { is_expected.to validate_presence_of(:target_type) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:current_user, :user)

    let(:params) { { new_acl:, target_type: } }
    let(:dependencies) { { guardian: } }
    let(:guardian) { current_user.guardian }
    let(:new_acl) do
      [{ type: "group", id: Group::AUTO_GROUPS[:logged_in_users], permission: "view" }]
    end
    let(:target) { Fabricate(:post) }
    let(:target_type) { "EvaluateModificationTestTargetClass" }

    class EvaluateModificationTestTargetClass < ActiveRecord::Base
      include AclTarget

      self.table_name = "posts"

      class << self
        def mandatory_acl
          [{ type: :group, id: Group::AUTO_GROUPS[:admins], permission: "manage" }]
        end

        def loss_warning_permissions
          []
        end
      end
    end

    context "when the target type does not exist" do
      let(:target_type) { "UnknownAclTarget" }

      it { is_expected.to fail_to_find_a_model(:target_type_klass) }
    end

    context "when the new ACL is empty" do
      let(:new_acl) { [] }

      it { is_expected.to fail_a_policy(:user_will_have_permission) }
    end

    context "when the new ACL is empty but the target has mandatory ACL entries that cover the current user" do
      let(:new_acl) { [] }

      before do
        current_user.grant_admin!
        guardian.user.reload
      end

      it { is_expected.to run_successfully }
    end

    context "when the new ACL is not empty" do
      fab!(:group)
      let(:new_acl) { [{ type: "group", id: group.id, permission: "edit" }] }

      context "when a group in the new ACL grants the current user permission" do
        before do
          group.add(current_user)
          guardian.user.reload
        end

        it { is_expected.to run_successfully }
      end

      context "when a user in the new ACL grants the current user permission" do
        let(:new_acl) { [{ type: "user", id: current_user.id, permission: "edit" }] }

        it { is_expected.to run_successfully }
      end

      context "when no entries grant the current user permission" do
        it { is_expected.to fail_a_policy(:user_will_have_permission) }
      end

      context "when the new ACL is missing a loss warning permission defined by the target" do
        before do
          EvaluateModificationTestTargetClass.stubs(:loss_warning_permissions).returns(["manage"])
        end

        it { is_expected.to fail_a_policy(:user_will_not_lose_permission) }
      end
    end
  end
end
