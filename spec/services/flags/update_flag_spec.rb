# frozen_string_literal: true

RSpec.describe(Flags::UpdateFlag) do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:id) }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:description) }
    it { is_expected.to validate_length_of(:name).is_at_most(Flag::MAX_NAME_LENGTH) }
    it { is_expected.to validate_length_of(:description).is_at_most(Flag::MAX_DESCRIPTION_LENGTH) }
    it { is_expected.to validate_inclusion_of(:applies_to).in_array(Flag.valid_applies_to_types) }
  end

  describe ".call" do
    subject(:result) { described_class.call(**params, **dependencies) }

    fab!(:current_user) { Fabricate(:admin) }
    fab!(:flag)

    let(:params) do
      {
        id: flag_id,
        name:,
        description:,
        applies_to:,
        require_message:,
        enabled:,
        auto_action_type:,
      }
    end
    let(:dependencies) { { guardian: current_user.guardian } }
    let(:flag_id) { flag.id }
    let(:name) { "edited custom flag name" }
    let(:description) { "edited custom flag description" }
    let(:applies_to) { ["Topic"] }
    let(:require_message) { true }
    let(:enabled) { false }
    let(:auto_action_type) { true }

    # DO NOT REMOVE: flags have side effects and their state will leak to
    # other examples otherwise.
    after { flag.destroy! }

    context "when contract is invalid" do
      let(:name) { nil }

      it { is_expected.to fail_a_contract }
    end

    context "when model is not found" do
      let(:flag_id) { 0 }

      it { is_expected.to fail_to_find_a_model(:flag) }
    end

    context "when the flag is a system one" do
      let(:flag) { Flag.first }

      it { is_expected.to fail_a_policy(:not_system) }
    end

    context "when the flag has been used" do
      let!(:post_action) { Fabricate(:post_action, post_action_type_id: flag.id) }

      it { is_expected.to fail_a_policy(:not_used) }
    end

    context "when user is not allowed to perform the action" do
      fab!(:current_user) { Fabricate(:user) }

      it { is_expected.to fail_a_policy(:invalid_access) }
    end

    context "when title is not unique" do
      let!(:flag_2) { Fabricate(:flag, name:) }

      # DO NOT REMOVE: flags have side effects and their state will leak to
      # other examples otherwise.
      after { flag_2.destroy! }

      it { is_expected.to fail_a_policy(:unique_name) }
    end

    context "when everything's ok" do
      it { is_expected.to run_successfully }

      it "updates the flag" do
        result
        expect(flag.reload).to have_attributes(
          name: "edited custom flag name",
          description: "edited custom flag description",
          applies_to: ["Topic"],
          require_message: true,
          enabled: false,
          auto_action_type: true,
        )
      end

      it "logs the action" do
        expect { result }.to change { UserHistory.count }.by(1)
        expect(UserHistory.last).to have_attributes(
          custom_type: "update_flag",
          details:
            "name: edited custom flag name\ndescription: edited custom flag description\napplies_to: [\"Topic\"]\nrequire_message: true\nenabled: false",
        )
      end
    end
  end
end
