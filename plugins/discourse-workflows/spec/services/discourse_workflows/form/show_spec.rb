# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Form::Show do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:uuid) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:user)
    fab!(:workflow) do
      graph =
        build_workflow_graph do |g|
          g.node "trigger-1",
                 "trigger:form",
                 configuration: {
                   "uuid" => "a1b2c3d4-e5f6-7890-abcd-ef0123456789",
                   "form_title" => "Test Form",
                   "form_description" => "A test form",
                   "form_fields" => [
                     { "field_label" => "Name", "field_type" => "text", "required" => true },
                   ],
                   "response_mode" => "on_received",
                 }
        end
      Fabricate(:discourse_workflows_workflow, enabled: true, **graph)
    end

    let(:dependencies) { { guardian: Guardian.new(user) } }
    let(:uuid) { "a1b2c3d4-e5f6-7890-abcd-ef0123456789" }
    let(:params) { { uuid: uuid } }

    before { DiscourseWorkflows::WorkflowDependencyIndexer.call(workflow) }

    context "when contract is invalid" do
      let(:uuid) { nil }

      it { is_expected.to fail_a_contract }
    end

    context "when workflow is not found" do
      let(:uuid) { "00000000-0000-0000-0000-000000000000" }

      it { is_expected.to fail_to_find_a_model(:workflow) }
    end

    context "when workflow is disabled" do
      before { workflow.update!(enabled: false) }

      it { is_expected.to fail_to_find_a_model(:workflow) }
    end

    context "when the form requires a logged-in user" do
      before do
        trigger_node = workflow.nodes.find { |n| n["type"] == "trigger:form" }
        trigger_node["configuration"]["authentication"] = "login_required"
        workflow.update!(nodes: workflow.nodes)
        DiscourseWorkflows::WorkflowDependencyIndexer.call(workflow)
      end

      context "without a current user" do
        let(:dependencies) { { guardian: Guardian.new } }

        it { is_expected.to fail_a_policy(:authenticated_if_required) }
      end

      context "with a current user" do
        it { is_expected.to run_successfully }
      end
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
          [
            {
              "field_label" => "Name",
              "field_type" => "text",
              "required" => true,
              "key" => "name",
            },
          ],
        )
        expect(form_data[:response_mode]).to eq("on_received")
        expect(form_data[:has_downstream_form]).to be(false)
      end

      it "returns a signed submission token without creating a waiting execution" do
        expect { result }.not_to change { DiscourseWorkflows::Execution.waiting.count }

        expect(result[:form_data][:resume_token]).to be_present
        expect(
          DiscourseWorkflows::FormTriggerToken.valid?(
            result[:form_data][:resume_token],
            workflow_id: workflow.id,
            trigger_node_id: "trigger-1",
            uuid: uuid,
          ),
        ).to be(true)
      end
    end

    context "when form_description references $execution.resume_url" do
      before do
        trigger_node = workflow.nodes.find { |n| n["type"] == "trigger:form" }
        trigger_node["configuration"]["form_description"] = "={{ $execution.resume_url }}"
        workflow.update!(nodes: workflow.nodes)
        DiscourseWorkflows::WorkflowDependencyIndexer.call(workflow)
      end

      it "resolves $execution.resume_url without materializing an execution" do
        expect(result).to run_successfully
        expect(result[:form_data][:form_description]).to eq("")
      end

      it "returns resume_token in the response" do
        expect(result).to run_successfully
        expect(result[:form_data][:resume_token]).to be_present
      end
    end

    context "when a non-adjacent downstream form action exists" do
      before do
        extra =
          build_workflow_graph do |g|
            g.node "action-1", "action:send_message"
            g.node "form-action-1", "action:form", configuration: { "form_fields" => [] }
            g.chain "trigger-1", "action-1", "form-action-1"
          end
        workflow.update!(nodes: workflow.nodes + extra[:nodes], connections: extra[:connections])
        DiscourseWorkflows::WorkflowDependencyIndexer.call(workflow)
      end

      it "detects the downstream form through intermediate nodes" do
        expect(result[:form_data][:has_downstream_form]).to be(true)
      end
    end

    context "with a waiting execution" do
      fab!(:waiting_workflow) do
        graph =
          build_workflow_graph do |g|
            g.node "trigger-1", "trigger:manual"
            g.node "form-action-1",
                   "action:form",
                   configuration: {
                     "form_title" => "Waiting Form",
                     "form_description" => "A waiting form",
                     "form_fields" => [
                       { "field_label" => "Feedback", "field_type" => "text", "required" => false },
                     ],
                   }
            g.chain "trigger-1", "form-action-1"
          end
        Fabricate(:discourse_workflows_workflow, enabled: true, **graph)
      end

      let(:resume_token) { SecureRandom.uuid }

      let(:execution) do
        allow(MessageBus).to receive(:publish)
        exec = DiscourseWorkflows::Executor.new(waiting_workflow, "trigger-1", {}).run
        exec.update!(resume_token: resume_token)
        exec
      end

      let(:params) { { uuid: uuid, resume_token: resume_token } }

      before { execution }

      it { is_expected.to run_successfully }

      it "builds waiting form data" do
        result
        form_data = result[:form_data]
        expect(form_data[:uuid]).to eq(uuid)
        expect(form_data[:form_title]).to eq("Waiting Form")
        expect(form_data[:form_description]).to eq("A waiting form")
        expect(form_data[:form_fields]).to eq(
          [
            {
              "field_label" => "Feedback",
              "field_type" => "text",
              "required" => false,
              "key" => "feedback",
            },
          ],
        )
        expect(form_data[:response_mode]).to eq("on_received")
        expect(form_data[:has_downstream_form]).to be(false)
        expect(form_data[:resume_token]).to eq(resume_token)
      end

      context "when form_description references $execution.resume_url" do
        fab!(:waiting_workflow) do
          graph =
            build_workflow_graph do |g|
              g.node "trigger-1", "trigger:manual"
              g.node "form-action-1",
                     "action:form",
                     configuration: {
                       "form_title" => "Waiting Form",
                       "form_description" => "={{ $execution.resume_url }}",
                       "form_fields" => [],
                     }
              g.chain "trigger-1", "form-action-1"
            end
          Fabricate(:discourse_workflows_workflow, enabled: true, **graph)
        end

        it "resolves $execution.resume_url from the execution context" do
          expect(result[:form_data][:form_description]).to eq(
            "#{Discourse.base_url}/workflows/webhooks/#{execution.id}?token=#{resume_token}",
          )
        end
      end

      context "when a downstream form action exists" do
        fab!(:waiting_workflow) do
          graph =
            build_workflow_graph do |g|
              g.node "trigger-1", "trigger:manual"
              g.node "form-action-1",
                     "action:form",
                     configuration: {
                       "form_title" => "Waiting Form",
                       "form_description" => "A waiting form",
                       "form_fields" => [],
                     }
              g.node "form-action-2", "action:form", configuration: { "form_fields" => [] }
              g.chain "trigger-1", "form-action-1", "form-action-2"
            end
          Fabricate(:discourse_workflows_workflow, enabled: true, **graph)
        end

        it "sets has_downstream_form to true" do
          expect(result[:form_data][:has_downstream_form]).to be(true)
        end
      end

      context "when a non-adjacent downstream form action exists" do
        fab!(:waiting_workflow) do
          graph =
            build_workflow_graph do |g|
              g.node "trigger-1", "trigger:manual"
              g.node "form-action-1",
                     "action:form",
                     configuration: {
                       "form_title" => "Waiting Form",
                       "form_description" => "A waiting form",
                       "form_fields" => [],
                     }
              g.node "action-between", "action:send_message"
              g.node "form-action-2", "action:form", configuration: { "form_fields" => [] }
              g.chain "trigger-1", "form-action-1", "action-between", "form-action-2"
            end
          Fabricate(:discourse_workflows_workflow, enabled: true, **graph)
        end

        it "detects the downstream form through intermediate nodes" do
          expect(result[:form_data][:has_downstream_form]).to be(true)
        end
      end

      context "when execution is not waiting" do
        before { execution.update!(status: :success) }

        it "falls back to initial form request path" do
          expect(result).to run_successfully
          expect(result[:form_data][:form_title]).to eq("Test Form")
        end
      end

      context "when the waiting node is not a form action" do
        before { execution.update!(waiting_node_id: "trigger-1") }

        it "falls back to initial form request path" do
          expect(result).to run_successfully
          expect(result[:form_data][:form_title]).to eq("Test Form")
        end
      end
    end
  end
end
