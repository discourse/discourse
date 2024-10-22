# frozen_string_literal: true

RSpec.describe(Flags::ToggleFlag) do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:flag_id) }
  end

  describe ".call" do
    subject(:result) { described_class.call(**params, **dependencies) }

    fab!(:current_user) { Fabricate(:admin) }
    fab!(:flag)

    let(:flag_id) { flag.id }
    let(:params) { { flag_id: flag_id } }
    let(:dependencies) { { guardian: current_user.guardian } }

    # DO NOT REMOVE: flags have side effects and their state will leak to
    # other examples otherwise.
    after { flag.destroy! }

    context "when user is not allowed to perform the action" do
      fab!(:current_user) { Fabricate(:user) }

      it { is_expected.to fail_a_policy(:invalid_access) }
    end

    context "when contract is invalid" do
      let(:flag_id) { nil }

      it { is_expected.to fail_a_contract }
    end

    context "when model is not found" do
      let(:flag_id) { 0 }

      it { is_expected.to fail_to_find_a_model(:flag) }
    end

    context "when everything's ok" do
      it { is_expected.to run_successfully }

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
end
