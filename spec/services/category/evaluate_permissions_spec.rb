# frozen_string_literal: true

RSpec.describe Category::EvaluatePermissions do
  describe described_class::Contract, type: :model do
    it { is_expected.to allow_values([], [1, 2]).for(:group_ids) }
    it { is_expected.not_to allow_values(["invalid"], [nil], [1, "invalid"]).for(:group_ids) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:current_user, :user)
    fab!(:group)
    fab!(:hidden_group) { Fabricate(:group, visibility_level: Group.visibility_levels[:owners]) }

    let(:params) { { group_ids: [group.id] } }
    let(:dependencies) { { guardian: current_user.guardian } }

    context "when the contract is invalid" do
      let(:params) { { group_ids: ["invalid"] } }

      it { is_expected.to fail_a_contract }
    end

    context "when the current user is an admin" do
      fab!(:current_user, :admin)

      it { is_expected.to run_successfully }
    end

    context "when the current user belongs to a permitted group" do
      before do
        group.add(current_user)
        current_user.reload
      end

      it { is_expected.to run_successfully }
    end

    context "when the current user's permitted group is hidden from them" do
      let(:params) { { group_ids: [hidden_group.id] } }

      before do
        hidden_group.add(current_user)
        current_user.reload
      end

      it { is_expected.to run_successfully }
    end

    context "when the current user does not belong to a permitted group" do
      it { is_expected.to fail_a_policy(:user_will_have_access) }
    end

    context "when permissions are empty and the current user is not staff" do
      let(:params) { { group_ids: [] } }

      it { is_expected.to fail_a_policy(:user_will_have_access) }
    end

    context "when permissions are empty and the current user is a moderator" do
      fab!(:current_user, :moderator)

      let(:params) { { group_ids: [] } }

      it { is_expected.to run_successfully }
    end

    context "when everyone is permitted with legacy pseudogroup behavior" do
      let(:params) { { group_ids: [Group::AUTO_GROUPS[:everyone]] } }

      before { SiteSetting.granular_anonymous_and_logged_in_groups_permissions = false }

      it { is_expected.to run_successfully }
    end

    context "when everyone is permitted with granular pseudogroup behavior" do
      let(:params) { { group_ids: [Group::AUTO_GROUPS[:everyone]] } }

      before { SiteSetting.granular_anonymous_and_logged_in_groups_permissions = true }

      it { is_expected.to fail_a_policy(:user_will_have_access) }
    end

    context "when logged-in users are permitted with granular pseudogroup behavior" do
      let(:params) { { group_ids: [Group::AUTO_GROUPS[:logged_in_users]] } }

      before { SiteSetting.granular_anonymous_and_logged_in_groups_permissions = true }

      it { is_expected.to run_successfully }
    end
  end
end
