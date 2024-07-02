# frozen_string_literal: true

RSpec.describe(Flags::UpdateFlag) do
  fab!(:flag)

  subject(:result) do
    described_class.call(
      id: flag.id,
      guardian: current_user.guardian,
      name: name,
      description: description,
      applies_to: applies_to,
      enabled: enabled,
    )
  end

  after { flag.destroy }

  let(:name) { "edited custom flag name" }
  let(:description) { "edited custom flag description" }
  let(:applies_to) { ["Topic"] }
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

    it "sets the service result as successful" do
      expect(result).to be_a_success
    end

    it "updates the flag" do
      result
      expect(flag.reload.name).to eq("edited custom flag name")
      expect(flag.description).to eq("edited custom flag description")
      expect(flag.applies_to).to eq(["Topic"])
      expect(flag.enabled).to be false
    end

    it "logs the action" do
      expect { result }.to change { UserHistory.count }.by(1)
      expect(UserHistory.last).to have_attributes(
        custom_type: "update_flag",
        details:
          "name: edited custom flag name\ndescription: edited custom flag description\napplies_to: [\"Topic\"]\nenabled: false",
      )
    end
  end
end
