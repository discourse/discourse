# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Variable::Update do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:key) }
    it { is_expected.to validate_presence_of(:value) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:admin)
    fab!(:variable, :discourse_workflows_variable)

    let(:params) do
      { variable_id: variable.id, key: "NEW_KEY", value: "new_value", description: "Updated" }
    end
    let(:dependencies) { { guardian: admin.guardian } }

    context "when contract is invalid" do
      let(:params) { { variable_id: variable.id, key: nil, value: nil } }

      it { is_expected.to fail_a_contract }
    end

    context "when variable does not exist" do
      let(:params) { { variable_id: -1, key: "X", value: "Y" } }

      it { is_expected.to fail_to_find_a_model(:variable) }
    end

    context "when user cannot manage workflows" do
      fab!(:user)

      let(:dependencies) { { guardian: user.guardian } }

      it { is_expected.to fail_a_policy(:can_manage_workflows) }
    end

    context "when everything's ok" do
      it { is_expected.to run_successfully }

      it "updates the variable" do
        expect { result }.to change { variable.reload.key }.to("NEW_KEY")
        expect(variable).to have_attributes(value: "new_value", description: "Updated")
      end

      it "logs a staff action" do
        expect { result }.to change { UserHistory.count }.by(1)
        expect(UserHistory.last).to have_attributes(
          custom_type: "discourse_workflows_variable_updated",
          subject: "NEW_KEY",
        )
      end
    end
  end
end
