# frozen_string_literal: true

RSpec.describe(Flags::CreateFlag) do
  subject(:result) { described_class.call(params:, **dependencies) }

  let(:params) { { name:, description:, applies_to:, require_message:, enabled: } }
  let(:dependencies) { { guardian: current_user.guardian } }
  let(:name) { "custom flag name" }
  let(:description) { "custom flag description" }
  let(:applies_to) { ["Topic"] }
  let(:enabled) { true }
  let(:require_message) { true }

  context "when user is not allowed to perform the action" do
    fab!(:current_user) { Fabricate(:user) }

    it { is_expected.to fail_a_policy(:invalid_access) }
  end

  context "when title is not unique" do
    fab!(:current_user) { Fabricate(:admin) }
    let!(:flag) { Fabricate(:flag, name: "custom flag name") }

    it { is_expected.to fail_a_policy(:unique_name) }
  end

  context "when applies to is invalid" do
    fab!(:current_user) { Fabricate(:admin) }
    let(:applies_to) { ["User"] }

    it { is_expected.to fail_a_contract }
  end

  context "when title is empty" do
    fab!(:current_user) { Fabricate(:admin) }
    let(:name) { nil }

    it { is_expected.to fail_a_contract }
  end

  context "when title is too long" do
    fab!(:current_user) { Fabricate(:admin) }
    let(:name) { "a" * 201 }

    it { is_expected.to fail_a_contract }
  end

  context "when description is empty" do
    fab!(:current_user) { Fabricate(:admin) }
    let(:description) { nil }

    it { is_expected.to fail_a_contract }
  end

  context "when description is too long" do
    fab!(:current_user) { Fabricate(:admin) }
    let(:description) { "a" * 1001 }

    it { is_expected.to fail_a_contract }
  end

  context "when user is allowed to perform the action" do
    fab!(:current_user) { Fabricate(:admin) }
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
