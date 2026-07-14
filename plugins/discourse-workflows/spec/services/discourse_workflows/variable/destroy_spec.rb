# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Variable::Destroy do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:variable_id) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:admin)
    fab!(:variable, :discourse_workflows_variable)

    let(:params) { { variable_id: variable.id } }
    let(:dependencies) { { guardian: admin.guardian } }

    context "when params are not valid" do
      let(:params) { {} }

      it { is_expected.to fail_a_contract }
    end

    context "when variable does not exist" do
      let(:params) { { variable_id: -1 } }

      it { is_expected.to fail_to_find_a_model(:variable) }
    end

    context "when user cannot manage workflows" do
      fab!(:user)

      let(:dependencies) { { guardian: user.guardian } }

      it { is_expected.to fail_a_policy(:can_manage_workflows) }
    end

    context "when everything's ok" do
      it { is_expected.to run_successfully }

      it "deletes the variable" do
        expect { result }.to change { DiscourseWorkflows::Variable.count }.by(-1)
      end

      it "logs a staff action" do
        expect { result }.to change { UserHistory.count }.by(1)
        expect(UserHistory.last).to have_attributes(
          custom_type: "discourse_workflows_variable_destroyed",
          subject: variable.key,
        )
      end
    end
  end
end
