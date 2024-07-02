# frozen_string_literal: true

RSpec.describe(Flags::CreateFlag) do
  subject(:result) do
    described_class.call(
      guardian: current_user.guardian,
      name: name,
      description: description,
      applies_to: applies_to,
      enabled: enabled,
    )
  end

  let(:name) { "custom flag name" }
  let(:description) { "custom flag description" }
  let(:applies_to) { ["Topic"] }
  let(:enabled) { true }

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

    after { Flag.destroy_by(name: "custom flag name") }

    it "sets the service result as successful" do
      expect(result).to be_a_success
    end

    it "creates the flag" do
      result
      flag = Flag.last
      expect(flag.name).to eq("custom flag name")
      expect(flag.description).to eq("custom flag description")
      expect(flag.applies_to).to eq(["Topic"])
      expect(flag.enabled).to be true
    end

    it "logs the action" do
      expect { result }.to change { UserHistory.count }.by(1)
      expect(UserHistory.last).to have_attributes(
        custom_type: "create_flag",
        details:
          "name: custom flag name\ndescription: custom flag description\napplies_to: [\"Topic\"]\nenabled: true",
      )
    end
  end
end
