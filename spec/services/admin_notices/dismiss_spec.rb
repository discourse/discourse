# frozen_string_literal: true

RSpec.describe(AdminNotices::Dismiss) do
  subject(:result) { described_class.call(id: admin_notice.id, guardian: current_user.guardian) }

  let!(:admin_notice) { Fabricate(:admin_notice, identifier: "problem.test") }
  let!(:problem_check) { Fabricate(:problem_check_tracker, identifier: "problem.test", blips: 3) }

  context "when user is not allowed to perform the action" do
    fab!(:current_user) { Fabricate(:user) }

    it { is_expected.to fail_a_policy(:invalid_access) }
  end

  context "when user is allowed to perform the action" do
    fab!(:current_user) { Fabricate(:admin) }

    it { is_expected.to run_successfully }

    it "sets the service result as successful" do
      expect(result).to be_a_success
    end

    it "destroys the admin notice" do
      expect { result }.to change { AdminNotice.count }.from(1).to(0)
    end

    it "resets any associated problem check" do
      expect { result }.to change { problem_check.reload.blips }.from(3).to(0)
    end
  end
end
