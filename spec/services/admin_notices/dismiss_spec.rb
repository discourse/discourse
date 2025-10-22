# frozen_string_literal: true

RSpec.describe(AdminNotices::Dismiss) do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:id) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:current_user, :admin)
    fab!(:admin_notice) { Fabricate(:admin_notice, identifier: "problem.test") }
    fab!(:problem_check) { Fabricate(:problem_check_tracker, identifier: "problem.test", blips: 3) }

    let(:params) { { id: notice_id } }
    let(:notice_id) { admin_notice.id }
    let(:dependencies) { { guardian: current_user.guardian } }

    context "when user is not allowed to perform the action" do
      fab!(:current_user, :user)

      it { is_expected.to fail_a_policy(:invalid_access) }
    end

    context "when data is invalid" do
      let(:notice_id) { nil }

      it { is_expected.to fail_a_contract }
    end

    context "when the admin notice has already been dismissed" do
      before { admin_notice.destroy! }

      it { is_expected.to run_successfully }
    end

    context "when everything's ok" do
      it { is_expected.to run_successfully }

      it "destroys the admin notice" do
        expect { result }.to change { AdminNotice.count }.from(1).to(0)
      end

      it "resets any associated problem check" do
        expect { result }.to change { problem_check.reload.blips }.from(3).to(0)
      end
    end
  end
end
