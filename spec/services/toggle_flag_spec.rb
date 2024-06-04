# frozen_string_literal: true

RSpec.describe(ToggleFlag) do
  subject(:result) { described_class.call(flag_id: flag.id, guardian: current_user.guardian) }

  let(:flag) { Flag.system.last }

  context "when user is not allowed to perform the action" do
    fab!(:current_user) { Fabricate(:user) }

    it { is_expected.to fail_a_policy(:invalid_access) }
  end

  context "when user is allowed to perform the action" do
    fab!(:current_user) { Fabricate(:admin) }

    it "sets the service result as successful" do
      expect(result).to be_a_success
    end

    it "toggles the flag" do
      expect(result[:flag].enabled).to be false
    end

    it "logs the action" do
      expect { result }.to change { UserHistory.count }.by(1)
      expect(UserHistory.last).to have_attributes(
        custom_type: "toggle_flag",
        details: "flag: #{result[:flag].name}\nenabled: #{result[:flag].enabled}",
      )
    end
  end
end
