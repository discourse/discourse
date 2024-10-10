# frozen_string_literal: true

RSpec.describe(Flags::UpdateFlag) do
  subject(:result) { described_class.call(params:, **dependencies) }

  fab!(:flag)

  let(:params) { { id: flag.id, name:, description:, applies_to:, require_message:, enabled: } }
  let(:dependencies) { { guardian: current_user.guardian } }
  let(:name) { "edited custom flag name" }
  let(:description) { "edited custom flag description" }
  let(:applies_to) { ["Topic"] }
  let(:require_message) { true }
  let(:enabled) { false }

  context "when user is not allowed to perform the action" do
    fab!(:current_user) { Fabricate(:user) }

    it { is_expected.to fail_a_policy(:invalid_access) }
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

  context "when title is not unique" do
    fab!(:current_user) { Fabricate(:admin) }
    fab!(:flag_2) { Fabricate(:flag, name: "edited custom flag name") }

    it { is_expected.to fail_a_policy(:unique_name) }

    after { Flag.destroy_by(name: "edited custom flag name") }
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

    it { is_expected.to run_successfully }

    it "updates the flag" do
      result
      expect(flag.reload).to have_attributes(
        name: "edited custom flag name",
        description: "edited custom flag description",
        applies_to: ["Topic"],
        require_message: true,
        enabled: false,
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
