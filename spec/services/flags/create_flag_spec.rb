# frozen_string_literal: true

RSpec.describe(Flags::CreateFlag) do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:description) }
    it { is_expected.to validate_length_of(:name).is_at_most(Flag::MAX_NAME_LENGTH) }
    it { is_expected.to validate_length_of(:description).is_at_most(Flag::MAX_DESCRIPTION_LENGTH) }
    it { is_expected.to validate_inclusion_of(:applies_to).in_array(Flag.valid_applies_to_types) }
  end

  describe ".call" do
    subject(:result) { described_class.call(**params, **dependencies) }

    fab!(:current_user) { Fabricate(:admin) }

    let(:params) do
      { name:, description:, applies_to:, require_message:, enabled:, auto_action_type: }
    end
    let(:dependencies) { { guardian: current_user.guardian } }
    let(:name) { "custom flag name" }
    let(:description) { "custom flag description" }
    let(:applies_to) { ["Topic"] }
    let(:enabled) { true }
    let(:require_message) { true }
    let(:auto_action_type) { true }

    context "when user is not allowed to perform the action" do
      fab!(:current_user) { Fabricate(:user) }

      it { is_expected.to fail_a_policy(:invalid_access) }
    end

    context "when contract is invalid" do
      let(:name) { nil }

      it { is_expected.to fail_a_contract }
    end

    context "when name is not unique" do
      let!(:flag) { Fabricate(:flag, name:) }

      it { is_expected.to fail_a_policy(:unique_name) }
    end

    context "when everything's ok" do
      let(:applies_to) { ["Topic::Custom"] }
      let(:flag) { Flag.last }

      before do
        DiscoursePluginRegistry.register_flag_applies_to_type(
          "Topic::Custom",
          OpenStruct.new(enabled?: true),
        )
      end

      it { is_expected.to run_successfully }

      it "creates the flag" do
        expect { result }.to change { Flag.count }.by(1)
        expect(flag).to have_attributes(
          name: "custom flag name",
          description: "custom flag description",
          applies_to: ["Topic::Custom"],
          require_message: true,
          enabled: true,
          notify_type: true,
          auto_action_type: true,
        )
      end

      it "logs the action" do
        expect { result }.to change { UserHistory.count }.by(1)
        expect(UserHistory.last).to have_attributes(
          custom_type: "create_flag",
          details:
            "name: custom flag name\ndescription: custom flag description\napplies_to: [\"Topic::Custom\"]\nrequire_message: true\nenabled: true",
        )
      end
    end
  end
end
