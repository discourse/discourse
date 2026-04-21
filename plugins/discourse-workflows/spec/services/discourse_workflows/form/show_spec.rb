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
        trigger_node = workflow.parsed_nodes.find { |n| n["type"] == "trigger:form" }
        trigger_node["configuration"]["authentication"] = "login_required"
        workflow.update!(nodes: workflow.parsed_nodes)
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
    end

    context "when form_description references $execution.resume_url" do
      before do
        trigger_node = workflow.parsed_nodes.find { |n| n["type"] == "trigger:form" }
        trigger_node["configuration"]["form_description"] = "={{ $execution.resume_url }}"
        workflow.update!(nodes: workflow.parsed_nodes)
        DiscourseWorkflows::WorkflowDependencyIndexer.call(workflow)
      end

      it "resolves $execution.resume_url to a valid webhook URL" do
        expect(result).to run_successfully
        description = result[:form_data][:form_description]
        expect(description).to match(%r{/workflows/webhooks/\d+\?token=[a-f0-9-]+})
      end

      it "returns resume_token in the response" do
        expect(result).to run_successfully
        expect(result[:form_data][:resume_token]).to be_present
      end

      it "creates a waiting execution for the form trigger" do
        expect { result }.to change { DiscourseWorkflows::Execution.waiting.count }.by(1)
        execution = DiscourseWorkflows::Execution.waiting.last
        expect(execution.waiting_config["wait_type"]).to eq("form_trigger")
        expect(execution.waiting_until).to be_within(5.seconds).of(1.hour.from_now)
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
        workflow.update!(
          nodes: workflow.parsed_nodes + extra[:nodes],
          connections: extra[:connections],
        )
        DiscourseWorkflows::WorkflowDependencyIndexer.call(workflow)
      end

      it "detects the downstream form through intermediate nodes" do
        expect(result[:form_data][:has_downstream_form]).to be(true)
      end
    end

    context "with a waiting execution" do
      before do
        extra =
          build_workflow_graph do |g|
            g.node "form-action-1",
                   "action:form",
                   configuration: {
                     "form_title" => "Waiting Form",
                     "form_description" => "A waiting form",
                     "form_fields" => [
                       { "field_label" => "Feedback", "field_type" => "text", "required" => false },
                     ],
                   }
          end
        workflow.update!(nodes: workflow.parsed_nodes + extra[:nodes])
      end

      let(:resume_token) { SecureRandom.uuid }

      fab!(:execution) do
        Fabricate(
          :discourse_workflows_execution,
          workflow: workflow,
          status: :waiting,
          waiting_node_id: "form-action-1",
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
      end

      context "when a downstream form action exists" do
        before do
          extra =
            build_workflow_graph do |g|
              g.node "form-action-2", "action:form", configuration: { "form_fields" => [] }
              g.connect "form-action-1", "form-action-2"
            end
          workflow.update!(
            nodes: workflow.parsed_nodes + extra[:nodes],
            connections: (workflow.parsed_connections || []) + extra[:connections],
          )
        end

        it "sets has_downstream_form to true" do
          expect(result[:form_data][:has_downstream_form]).to be(true)
        end
      end

      context "when a non-adjacent downstream form action exists" do
        before do
          extra =
            build_workflow_graph do |g|
              g.node "action-between", "action:send_message"
              g.node "form-action-2", "action:form", configuration: { "form_fields" => [] }
              g.chain "form-action-1", "action-between", "form-action-2"
            end
          workflow.update!(
            nodes: workflow.parsed_nodes + extra[:nodes],
            connections: (workflow.parsed_connections || []) + extra[:connections],
          )
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

      context "when execution wait_type is not form" do
        before do
          execution.update!(
            waiting_config: execution.waiting_config.merge("wait_type" => "webhook"),
          )
        end

        it "falls back to initial form request path" do
          expect(result).to run_successfully
          expect(result[:form_data][:form_title]).to eq("Test Form")
        end
      end
    end
  end
end
