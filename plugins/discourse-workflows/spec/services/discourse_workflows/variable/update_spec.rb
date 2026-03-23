# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Variable::Update do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:key) }
    it { is_expected.to validate_presence_of(:value) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, guardian: admin.guardian) }

    fab!(:admin)
    fab!(:variable, :discourse_workflows_variable)

    let(:params) do
      { variable_id: variable.id, key: "NEW_KEY", value: "new_value", description: "Updated" }
    end

    before { SiteSetting.discourse_workflows_enabled = true }

    context "when contract is invalid" do
      let(:params) { { variable_id: variable.id, key: nil, value: nil } }

      it { is_expected.to fail_a_contract }
    end

    context "when variable does not exist" do
      let(:params) { { variable_id: -1, key: "X", value: "Y" } }

      it { is_expected.to fail_to_find_a_model(:variable) }
    end

    context "when everything's ok" do
      it { is_expected.to run_successfully }

      it "updates the variable" do
        result
        expect(variable.reload).to have_attributes(
          key: "NEW_KEY",
          value: "new_value",
          description: "Updated",
        )
      end

      it "logs a staff action" do
        result
        log = UserHistory.last
        expect(log.custom_type).to eq("discourse_workflows_variable_updated")
        expect(log.subject).to eq("NEW_KEY")
      end
    end
  end
end
