# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Workflow::Destroy do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:workflow_id) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:admin)
    fab!(:workflow) { Fabricate(:discourse_workflows_workflow, created_by: admin) }

    let(:params) { { workflow_id: workflow.id } }
    let(:dependencies) { { guardian: admin.guardian } }

    before { SiteSetting.discourse_workflows_enabled = true }

    context "when contract is invalid" do
      let(:params) { { workflow_id: nil } }

      it { is_expected.to fail_a_contract }
    end

    context "when workflow does not exist" do
      let(:params) { { workflow_id: -1 } }

      it { is_expected.to fail_to_find_a_model(:workflow) }
    end

    context "when user cannot manage workflows" do
      fab!(:user)
      let(:dependencies) { { guardian: user.guardian } }

      it { is_expected.to fail_a_policy(:can_manage_workflows) }
    end

    context "when everything's ok" do
      it { is_expected.to run_successfully }

      it "destroys the workflow" do
        expect { result }.to change { DiscourseWorkflows::Workflow.exists?(workflow.id) }.to(false)
      end

      it "logs a staff action" do
        expect { result }.to change {
          UserHistory.where(custom_type: "discourse_workflows_workflow_destroyed").count
        }.by(1)
      end

      it "clears the site cache" do
        Site.expects(:clear_cache).once
        result
      end
    end
  end
end
