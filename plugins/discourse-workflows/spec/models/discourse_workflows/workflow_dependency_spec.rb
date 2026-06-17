# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::WorkflowDependency do
  fab!(:admin)

  before { described_class.clear_cache! }

  def index(workflow)
    version = workflow.workflow_versions.find_by(version_id: workflow.version_id)
    DiscourseWorkflows::WorkflowDependencyIndexer.call(workflow, version: version)
  end

  describe ".cached_user_modals?" do
    it "is true when a workflow uses the modal node" do
      graph =
        build_workflow_graph do |g|
          g.node "t1", "trigger:manual"
          g.node "m1",
                 "action:modal",
                 configuration: {
                   "title" => "Approve?",
                   "buttons" => {
                     "values" => [{ "label" => "Approve", "value" => "approve" }],
                   },
                 }
          g.chain "t1", "m1"
        end
      workflow = Fabricate(:discourse_workflows_workflow, created_by: admin, **graph)
      index(workflow)

      expect(described_class.cached_user_modals?).to eq(true)
    end

    it "is false when no workflow uses the modal node" do
      graph =
        build_workflow_graph do |g|
          g.node "t1", "trigger:manual"
          g.node "a1", "action:topic"
          g.chain "t1", "a1"
        end
      workflow = Fabricate(:discourse_workflows_workflow, created_by: admin, **graph)
      index(workflow)

      expect(described_class.cached_user_modals?).to eq(false)
    end
  end
end
