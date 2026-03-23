# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Variable::Delete do
  describe ".call" do
    subject(:result) { described_class.call(params:, guardian: admin.guardian) }

    fab!(:admin)
    fab!(:variable, :discourse_workflows_variable)

    let(:params) { { variable_id: variable.id } }

    before { SiteSetting.discourse_workflows_enabled = true }

    context "when variable does not exist" do
      let(:params) { { variable_id: -1 } }

      it { is_expected.to fail_to_find_a_model(:variable) }
    end

    context "when everything's ok" do
      it { is_expected.to run_successfully }

      it "deletes the variable" do
        result
        expect(DiscourseWorkflows::Variable.exists?(variable.id)).to eq(false)
      end

      it "logs a staff action" do
        result
        log = UserHistory.last
        expect(log.custom_type).to eq("discourse_workflows_variable_destroyed")
        expect(log.subject).to eq(variable.key)
      end
    end
  end
end
