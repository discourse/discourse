# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Form::Show do
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
          "form_description" => "A test form",
          "form_fields" => [
            { "field_label" => "Name", "field_type" => "text", "required" => true },
          ],
          "response_mode" => "on_received",
        },
      )
    end

    let(:uuid) { "a1b2c3d4-e5f6-7890-abcd-ef0123456789" }
    let(:params) { { uuid: uuid } }

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

    context "when form node is not found" do
      let(:uuid) { "00000000-0000-0000-0000-000000000000" }

      it { is_expected.to fail_to_find_a_model(:form_node) }
    end

    context "when workflow is disabled" do
      before { workflow.update!(enabled: false) }

      it { is_expected.to fail_to_find_a_model(:form_node) }
    end

    context "with an initial form request" do
      it { is_expected.to run_successfully }

      it "builds trigger form data" do
        result
        form_data = result[:form_data]
        expect(form_data[:uuid]).to eq(uuid)
        expect(form_data[:form_title]).to eq("Test Form")
        expect(form_data[:form_description]).to eq("A test form")
        expect(form_data[:form_fields]).to eq(
          [{ "field_label" => "Name", "field_type" => "text", "required" => true }],
        )
        expect(form_data[:response_mode]).to eq("on_received")
      end
    end

    context "with a waiting execution" do
      fab!(:form_action_node) do
        Fabricate(
          :discourse_workflows_node,
          workflow: workflow,
          type: "action:form",
          name: "Form Action",
          configuration: {
            "form_title" => "Waiting Form",
            "form_description" => "A waiting form",
            "form_fields" => [
              { "field_label" => "Feedback", "field_type" => "text", "required" => false },
            ],
          },
        )
      end

      let(:resume_token) { SecureRandom.uuid }

      fab!(:execution) do
        Fabricate(
          :discourse_workflows_execution,
          workflow: workflow,
          status: :waiting,
          waiting_node_id: form_action_node.id,
          waiting_config: {
            "wait_type" => "form",
            "resume_token" => "placeholder",
            "form_title" => "Waiting Form",
            "form_description" => "A waiting form",
            "form_fields" => [
              { "field_label" => "Feedback", "field_type" => "text", "required" => false },
            ],
          },
        )
      end

      let(:params) { { uuid: uuid, resume_token: resume_token } }

      before do
        execution.update!(
          waiting_config: execution.waiting_config.merge("resume_token" => resume_token),
        )
      end

      it { is_expected.to run_successfully }

      it "builds waiting form data" do
        result
        form_data = result[:form_data]
        expect(form_data[:uuid]).to eq(uuid)
        expect(form_data[:form_title]).to eq("Waiting Form")
        expect(form_data[:form_description]).to eq("A waiting form")
        expect(form_data[:form_fields]).to eq(
          [{ "field_label" => "Feedback", "field_type" => "text", "required" => false }],
        )
        expect(form_data[:response_mode]).to eq("on_received")
      end

      context "when execution is not waiting" do
        before { execution.update!(status: :success) }

        it "falls back to initial form request path" do
          expect(result).to run_successfully
          expect(result[:form_data][:form_title]).to eq("Test Form")
        end
      end

      context "when execution wait_type is not form" do
        before { execution.update!(waiting_config: { "wait_type" => "approval" }) }

        it "falls back to initial form request path" do
          expect(result).to run_successfully
          expect(result[:form_data][:form_title]).to eq("Test Form")
        end
      end
    end
  end
end
