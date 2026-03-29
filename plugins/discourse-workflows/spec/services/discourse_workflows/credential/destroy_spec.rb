# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Credential::Destroy do
  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:admin)
    fab!(:credential, :discourse_workflows_credential)

    let(:params) { { credential_id: credential.id } }
    let(:dependencies) { { guardian: admin.guardian } }

    context "when credential not found" do
      let(:params) { { credential_id: -1 } }

      it { is_expected.to fail_to_find_a_model(:credential) }
    end

    context "when user cannot manage workflows" do
      fab!(:user)

      let(:dependencies) { { guardian: user.guardian } }

      it { is_expected.to fail_a_policy(:can_manage_workflows) }
    end

    context "when credential is referenced by a workflow node" do
      fab!(:workflow) do
        Fabricate(:discourse_workflows_workflow, name: "My Workflow", created_by: admin)
      end
      fab!(:node) do
        Fabricate(
          :discourse_workflows_node,
          workflow: workflow,
          type: "trigger:webhook",
          name: "Webhook",
          configuration: {
            "credential_id" => credential.id,
          },
        )
      end

      it { is_expected.to fail_a_policy(:not_referenced_by_workflows) }
    end

    context "when everything is valid" do
      it { is_expected.to run_successfully }

      it "destroys the credential" do
        expect { result }.to change { DiscourseWorkflows::Credential.count }.by(-1)
      end

      it "logs a staff action" do
        expect { result }.to change { UserHistory.count }.by(1)
        expect(UserHistory.last).to have_attributes(
          custom_type: "discourse_workflows_credential_destroyed",
          subject: credential.name,
        )
      end
    end
  end
end
