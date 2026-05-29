# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Workflow::Create do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_length_of(:name).is_at_most(100) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:user, :admin)

    let(:params) { { name:, nodes:, connections:, static_data: } }
    let(:dependencies) { { guardian: user.guardian } }
    let(:name) { "My Workflow" }
    let(:nodes) { [] }
    let(:connections) { {} }
    let(:static_data) { {} }

    context "when contract is invalid" do
      let(:name) { nil }

      it { is_expected.to fail_a_contract }
    end

    context "when name is too long" do
      let(:name) { "a" * 101 }

      it { is_expected.to fail_a_contract }
    end

    context "when connections use an unsupported array shape" do
      let(:connections) { [{ source_index: 0, target_index: 1 }] }

      it { is_expected.to fail_a_step(:populate_graph) }
    end

    context "when nodes use unsupported snake_case workflow JSON keys" do
      let(:nodes) { [{ type: "trigger:manual", type_version: "1.0", name: "Manual" }] }

      it { is_expected.to fail_a_step(:populate_graph) }
    end

    context "when static_data uses a nested node bucket" do
      let(:static_data) { { "node" => { "Manual" => {} } } }

      it { is_expected.to fail_a_contract }
    end

    context "when static_data has a non-object slot" do
      let(:static_data) { { "global" => "bad" } }

      it { is_expected.to fail_a_contract }
    end

    context "when two nodes share the same name" do
      let(:nodes) do
        [
          { id: "a", type: "trigger:manual", name: "Step" },
          { id: "b", type: "action:log", name: "Step" },
        ]
      end

      it { is_expected.to fail_a_step(:populate_graph) }
    end

    context "when two sticky notes share the same default name" do
      let(:nodes) do
        [
          { id: "note-1", type: "flow:sticky_note", name: "Sticky Note" },
          { id: "note-2", type: "flow:sticky_note", name: "Sticky Note" },
        ]
      end

      it { is_expected.to run_successfully }
    end

    context "when user cannot manage workflows" do
      fab!(:user)

      it { is_expected.to fail_a_policy(:can_manage_workflows) }
    end

    context "when graph population fails" do
      before { DiscourseWorkflows::Workflow::Action::PopulateGraph.stubs(:call).returns(false) }

      it { is_expected.to fail_a_step(:populate_graph) }
    end

    context "when everything's ok" do
      let(:nodes) do
        [
          {
            id: "node_1",
            type: "trigger:topic_created",
            name: "Topic Created",
            parameters: {
              category_id: 1,
            },
          },
          {
            id: "node_2",
            type: "action:topic_tags",
            name: "Topic Tags",
            parameters: {
              tag_names: "test",
            },
          },
        ]
      end
      let(:connections) do
        {
          "Topic Created" => {
            "main" => [[{ "node" => "Topic Tags", "type" => "main", "index" => 0 }]],
          },
        }
      end
      let(:static_data) do
        { "global" => { "tenant_id" => "acme" }, "node:Topic Created" => { "cursor" => "abc" } }
      end

      it { is_expected.to run_successfully }

      it "creates a workflow with correct attributes" do
        result
        expect(result[:workflow]).to have_attributes(
          name: "My Workflow",
          created_by: user,
          updated_by: user,
        )
        expect(result[:workflow]).not_to be_published
      end

      it "stores static data without reshaping it" do
        result

        expect(result[:workflow].static_data).to eq(JSON.parse(static_data.to_json))
      end

      it "populates the workflow graph" do
        result
        workflow = result[:workflow].reload
        expect(workflow.nodes.size).to eq(2)
        expect(workflow.connections).to eq(
          "Topic Created" => {
            "main" => [[{ "node" => "Topic Tags", "type" => "main", "index" => 0 }]],
          },
        )
      end

      it "creates the initial snapshot tagged with the workflow's versionId" do
        result
        workflow = result[:workflow].reload
        snapshot = workflow.workflow_versions.find_by(version_id: workflow.version_id)
        expect(snapshot).to have_attributes(
          name: "My Workflow",
          nodes: workflow.nodes,
          connections: workflow.connections,
        )
        expect(workflow.active_version_id).to be_nil
      end

      it "logs a staff action" do
        result
        log = UserHistory.last
        expect(log.custom_type).to eq("discourse_workflows_workflow_created")
        expect(log.subject).to eq("My Workflow")
      end

      it_behaves_like "expires workflow caches"
    end
  end
end
