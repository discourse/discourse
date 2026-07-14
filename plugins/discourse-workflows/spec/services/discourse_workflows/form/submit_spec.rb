# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Form::Submit do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:uuid) }
    it { is_expected.to allow_value({}).for(:form_data) }
    it { is_expected.not_to allow_value("string").for(:form_data) }
    it { is_expected.not_to allow_value([]).for(:form_data) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:user)
    let(:dependencies) { { guardian: Guardian.new(user) } }

    fab!(:workflow) do
      graph =
        build_workflow_graph do |g|
          g.node "trigger-1",
                 "trigger:form",
                 configuration: {
                   "uuid" => "a1b2c3d4-e5f6-7890-abcd-ef0123456789",
                   "form_title" => "Test Form",
                   "form_fields" => [
                     { "field_label" => "Name", "field_type" => "text", "required" => true },
                   ],
                   "response_mode" => "on_received",
                 }
        end
      Fabricate(:discourse_workflows_workflow, published: true, **graph)
    end

    let(:uuid) { "a1b2c3d4-e5f6-7890-abcd-ef0123456789" }
    let(:resume_token) do
      DiscourseWorkflows::FormTriggerToken.generate(
        workflow_id: workflow.id,
        trigger_node_id: "trigger-1",
        uuid: uuid,
      )
    end
    let(:form_data) { { "name" => "Test User" } }
    let(:params) { { uuid: uuid, resume_token: resume_token, form_data: form_data } }

    before { DiscourseWorkflows::WorkflowDependencyIndexer.call(workflow) }

    context "when the contract is invalid" do
      let(:uuid) { nil }

      it { is_expected.to fail_a_contract }
    end

    context "when the workflow is not found" do
      let(:uuid) { "00000000-0000-0000-0000-000000000000" }

      it { is_expected.to fail_to_find_a_model(:published_trigger) }
    end

    context "when the workflow is unpublished" do
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

    context "when required form fields are missing" do
      let(:form_data) { {} }

      it { is_expected.to fail_a_step(:ensure_form_valid) }

      it "sets the missing field error" do
        expect(result[:form_validation].errors.map(&:to_h)).to contain_exactly(
          { field_label: "Name", code: :missing },
        )
      end
    end

    context "when required form fields are blank" do
      let(:form_data) { { "name" => "" } }

      it { is_expected.to fail_a_step(:ensure_form_valid) }
    end

    context "when a number field receives a non-numeric value" do
      let(:uuid) { "11111111-2222-3333-4444-555555555555" }

      fab!(:workflow) do
        graph =
          build_workflow_graph do |g|
            g.node "trigger-1",
                   "trigger:form",
                   configuration: {
                     "uuid" => "11111111-2222-3333-4444-555555555555",
                     "form_title" => "Test Form",
                     "form_fields" => [
                       { "field_label" => "Age", "field_type" => "number", "required" => true },
                     ],
                     "response_mode" => "on_received",
                   }
          end
        Fabricate(:discourse_workflows_workflow, published: true, **graph)
      end

      let(:form_data) { { "age" => "abc" } }

      it { is_expected.to fail_a_step(:ensure_form_valid) }

      it "reports the invalid value" do
        expect(result[:form_validation].errors.map(&:to_h)).to contain_exactly(
          { field_label: "Age", code: :invalid_value },
        )
      end
    end

    context "when the initial submission token is missing" do
      let(:resume_token) { nil }

      it { is_expected.to fail_a_policy(:valid_initial_submission_token) }
    end

    context "when the initial submission token is invalid" do
      let(:resume_token) { "invalid-token" }

      it { is_expected.to fail_a_policy(:valid_initial_submission_token) }
    end

    context "when everything's ok" do
      it { is_expected.to run_successfully }

      it "creates an execution" do
        expect { result }.to change { DiscourseWorkflows::Execution.count }.by(1)
      end

      it "sets the execution in the context" do
        result
        expect(result[:execution]).to be_a(DiscourseWorkflows::Execution)
      end

      it "stores a compatible top-level trigger payload" do
        freeze_time Time.utc(2026, 1, 1)

        result

        expect(result[:execution].trigger_data).to include(
          "name" => "Test User",
          "submitted_at" => "2026-01-01T00:00:00.000Z",
          "form_mode" => "production",
        )
        expect(result[:execution].trigger_data).not_to have_key("form_data")
      end

      it "computes response metadata" do
        result
        expect(result[:response_metadata]).to include(
          has_downstream_form: false,
          response_mode: "on_received",
        )
      end

      context "with a long form field value" do
        let(:form_data) { { "name" => "a" * 10_001 } }

        it "stores the truncated value in trigger data" do
          result

          stored_name = result[:execution].trigger_data["name"]
          expect(stored_name.length).to eq(
            DiscourseWorkflows::Schemas::FormFields::MAX_FIELD_VALUE_LENGTH,
          )
        end
      end

      context "with hidden form fields" do
        before do
          trigger_node = workflow.nodes.find { |node| node["id"] == "trigger-1" }
          trigger_node["parameters"]["form_fields"] = [
            { "field_label" => "Name", "field_type" => "text", "required" => true },
            {
              "field_label" => "Tracking ID",
              "field_name" => "tracking_id",
              "field_type" => "hiddenField",
              "field_value" => "server-value",
            },
          ]
          workflow.update!(nodes: workflow.nodes)
          publish_workflow!(workflow)
        end

        let(:form_data) { { "name" => "Test User", "tracking_id" => "client-value" } }

        it "stores the configured hidden value instead of the client-submitted value" do
          result

          expect(result[:execution].trigger_data).to include(
            "name" => "Test User",
            "tracking_id" => "server-value",
          )
        end
      end

      context "with query-backed hidden form fields" do
        before do
          trigger_node = workflow.nodes.find { |node| node["id"] == "trigger-1" }
          trigger_node["parameters"]["form_fields"] = [
            { "field_label" => "Name", "field_type" => "text", "required" => true },
            {
              "field_label" => "Tracking ID",
              "field_name" => "tracking_id",
              "field_type" => "hiddenField",
            },
          ]
          workflow.update!(nodes: workflow.nodes)
          publish_workflow!(workflow)
        end

        let(:resume_token) do
          DiscourseWorkflows::FormTriggerToken.generate(
            workflow_id: workflow.id,
            trigger_node_id: "trigger-1",
            uuid: uuid,
            form_query_parameters: {
              tracking_id: "query-value",
            },
          )
        end
        let(:form_data) { { "name" => "Test User", "tracking_id" => "client-value" } }

        it "stores the signed query value instead of the client-submitted value" do
          result

          expect(result[:execution].trigger_data).to include(
            "name" => "Test User",
            "tracking_id" => "query-value",
          )
        end
      end

      context "when the initial form URL had query parameters" do
        let(:resume_token) do
          DiscourseWorkflows::FormTriggerToken.generate(
            workflow_id: workflow.id,
            trigger_node_id: "trigger-1",
            uuid: uuid,
            form_query_parameters: {
              source: "email",
              ref: "spring",
            },
          )
        end

        it "stores form_query_parameters on the trigger payload" do
          result

          expect(result[:execution].trigger_data["form_query_parameters"]).to eq(
            "source" => "email",
            "ref" => "spring",
          )
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
          expect(result[:response_metadata]).to include(has_downstream_form: true)
        end
      end
    end
  end
end
