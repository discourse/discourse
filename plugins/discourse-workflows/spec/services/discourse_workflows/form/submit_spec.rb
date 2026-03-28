# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Form::Submit do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:uuid) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:user)
    let(:dependencies) { { guardian: Guardian.new(user) } }

    fab!(:workflow) { Fabricate(:discourse_workflows_workflow, enabled: true) }
    fab!(:trigger_node) do
      Fabricate(
        :discourse_workflows_node,
        workflow: workflow,
        type: "trigger:form",
        name: "Form Trigger",
        configuration: {
          "uuid" => "a1b2c3d4-e5f6-7890-abcd-ef0123456789",
          "form_title" => "Test Form",
          "form_fields" => [
            { "field_label" => "Name", "field_type" => "text", "required" => true },
          ],
          "response_mode" => "on_received",
        },
      )
    end

    let(:uuid) { "a1b2c3d4-e5f6-7890-abcd-ef0123456789" }
    let(:form_data) { { "name" => "Test User" } }
    let(:params) { { uuid: uuid, form_data: form_data } }

    before do
      SiteSetting.discourse_workflows_enabled = true
      DiscourseWorkflows::Registry.reset!
      DiscourseWorkflows::Registry.register_trigger(DiscourseWorkflows::Triggers::Form::V1)
    end

    after { DiscourseWorkflows::Registry.reset! }

    context "when contract is invalid" do
      let(:uuid) { nil }

      it { is_expected.to fail_a_contract }
    end

    context "when trigger node is not found" do
      let(:uuid) { "00000000-0000-0000-0000-000000000000" }

      it { is_expected.to fail_to_find_a_model(:trigger_node) }
    end

    context "when workflow is disabled" do
      before { workflow.update!(enabled: false) }

      it { is_expected.to fail_to_find_a_model(:trigger_node) }
    end

    context "when everything is valid" do
      it { is_expected.to run_successfully }

      it "creates an execution" do
        expect { result }.to change { DiscourseWorkflows::Execution.count }.by(1)
      end

      it "sets the execution in the context" do
        result
        expect(result[:execution]).to be_a(DiscourseWorkflows::Execution)
      end

      it "computes response metadata" do
        result
        expect(result[:response_metadata]).to include(
          has_downstream_form: false,
          response_mode: "on_received",
        )
      end
    end
  end
end
