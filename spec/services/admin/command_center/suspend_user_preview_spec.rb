# frozen_string_literal: true

RSpec.describe Admin::CommandCenter::SuspendUserPreview do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:command) }
    it { is_expected.to validate_length_of(:command).is_at_most(500) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:admin)
    fab!(:user) { Fabricate(:user, username: "markvanlan") }

    let(:params) { { command: } }
    let(:dependencies) { { guardian: admin.guardian } }
    let(:command) { "Suspend markvanlan for spam" }

    it { is_expected.to run_successfully }

    it "returns a suspension preview without mutating the user" do
      expect(result.payload).to include(
        intent: "suspend_user",
        user: include(username: "markvanlan"),
        suspension: include(reason: "spam"),
      )
      expect(user.reload).not_to be_suspended
    end

    context "with an unsupported command" do
      let(:command) { "Delete markvanlan" }

      it { is_expected.to fail_a_step(:parse_command) }
    end

    context "when the user does not exist" do
      let(:command) { "Suspend missinguser" }

      it { is_expected.to fail_to_find_a_model(:user) }
    end

    context "when the target cannot be suspended" do
      let(:command) { "Suspend #{admin.username}" }

      it { is_expected.to fail_a_policy(:can_suspend_user) }
    end
  end

  describe ".normalize_duration_text" do
    it "normalizes supported durations and rejects unsupported ones" do
      expect(described_class.normalize_duration_text("7 days")).to eq("7 days")
      expect(described_class.normalize_duration_text("one week")).to eq("one week")
      expect(described_class.normalize_duration_text("until 2026-06-01")).to eq("until 2026-06-01")
      expect(described_class.normalize_duration_text("forever")).to eq(nil)
    end
  end
end
