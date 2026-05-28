# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Form::Show do
  describe described_class::Contract, type: :model do
    it "requires uuid for initial form requests" do
      contract = described_class.new
      expect(contract).not_to be_valid
      expect(contract.errors[:uuid]).to be_present
    end
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
      Fabricate(:discourse_workflows_workflow, published: true, **graph)
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

      it { is_expected.to fail_to_find_a_model(:published_trigger) }
    end

    context "when workflow is unpublished" do
      before { unpublish_workflow!(workflow) }

      it { is_expected.to fail_to_find_a_model(:published_trigger) }
    end

    context "when the form requires a logged-in user" do
      before do
        trigger_node = workflow.nodes.find { |n| n["type"] == "trigger:form" }
        trigger_node["parameters"]["authentication"] = "login_required"
        workflow.update!(nodes: workflow.nodes)
        publish_workflow!(workflow)
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
        expect(form_data[:form_title]).to eq("Test Form")
        expect(form_data[:form_description]).to eq("A test form")
        expect(form_data[:response_mode]).to eq("on_received")
        expect(form_data[:has_downstream_form]).to be(false)
        expect(form_data[:form_submit_url]).to eq("/workflows/form/#{uuid}.json")
        expect(form_data).not_to have_key(:form_fields)
        expect(form_data).to include(
          data: {
            "name" => "",
          },
          fields: [
            {
              name: "name",
              title: "Name",
              type: "input",
              validation: "required",
              autofocus: false,
            },
          ],
        )
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

      context "with URL query parameters" do
        let(:params) do
          { uuid: uuid, form_query_parameters: { "name" => "Query User", "source" => "email" } }
        end

        it "uses matching query parameters as field defaults" do
          expect(result[:form_data][:data]["name"]).to eq("Query User")
        end

        it "persists query parameters in the signed submission token" do
          token_payload =
            DiscourseWorkflows::FormTriggerToken.payload(
              result[:form_data][:resume_token],
              workflow_id: workflow.id,
              trigger_node_id: "trigger-1",
              uuid: uuid,
            )

          expect(token_payload["form_query_parameters"]).to eq(
            "name" => "Query User",
            "source" => "email",
          )
        end
      end

      context "with hidden fields and URL query parameters" do
        let(:params) do
          { uuid: uuid, form_query_parameters: { "tracking_id" => "query-tracking" } }
        end

        before do
          trigger_node = workflow.nodes.find { |node| node["id"] == "trigger-1" }
          trigger_node["parameters"]["form_fields"] = [
            {
              "field_label" => "Tracking ID",
              "field_name" => "tracking_id",
              "field_type" => "hiddenField",
            },
          ]
          workflow.update!(nodes: workflow.nodes)
          publish_workflow!(workflow)
        end

        it "keeps hidden values server-side and out of public form data" do
          expect(result[:form_data]).not_to have_key(:form_fields)
          expect(result[:form_data][:data]).to be_empty
          expect(result[:form_data][:fields]).to be_empty
        end
      end

      context "when the draft workflow name changes after publishing" do
        before do
          trigger_node = workflow.nodes.find { |node| node["id"] == "trigger-1" }
          trigger_node["parameters"]["form_title"] = "={{ $execution.workflow_name }}"
          workflow.update!(nodes: workflow.nodes)
          publish_workflow!(workflow)
          workflow.update!(name: "Draft workflow name")
        end

        it "uses the published workflow name in execution expressions" do
          expect(result[:form_data][:form_title]).to eq(workflow.active_version.name)
        end
      end
    end

    context "when form_description references $execution.resume_url" do
      before do
        trigger_node = workflow.nodes.find { |n| n["type"] == "trigger:form" }
        trigger_node["parameters"]["form_description"] = "={{ $execution.resume_url }}"
        workflow.update!(nodes: workflow.nodes)
        publish_workflow!(workflow)
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

    context "when form_description references $execution.resumeFormUrl" do
      before do
        trigger_node = workflow.nodes.find { |n| n["type"] == "trigger:form" }
        trigger_node["parameters"]["form_description"] = "={{ $execution.resumeFormUrl }}"
        workflow.update!(nodes: workflow.nodes)
        publish_workflow!(workflow)
      end

      it "resolves $execution.resumeFormUrl without materializing an execution" do
        expect(result).to run_successfully
        expect(result[:form_data][:form_description]).to eq("")
      end
    end

    context "when a non-adjacent downstream form action exists" do
      before do
        extra =
          build_workflow_graph do |g|
            g.node "action-1", "action:send_message"
            g.node "form-action-1", "action:form", configuration: { "form_fields" => [] }
          end
        nodes = workflow.nodes + extra[:nodes]
        workflow.update!(
          nodes: nodes,
          connections:
            workflow_connections_for(nodes, %w[trigger-1 action-1], %w[action-1 form-action-1]),
        )
        publish_workflow!(workflow)
      end

      it "detects the downstream form through intermediate nodes" do
        expect(result[:form_data][:has_downstream_form]).to be(true)
      end
    end
  end
end
