# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::WorkflowDependency do
  fab!(:user)

  before { described_class.clear_cache! }
  after { described_class.clear_cache! }

  describe ".active_node_types" do
    it "returns the node types referenced by the active version of a published workflow" do
      graph = build_workflow_graph { |g| g.node "trigger-1", "trigger:topic_closed" }
      Fabricate(:discourse_workflows_workflow, created_by: user, published: true, **graph)

      expect(described_class.active_node_types).to include("trigger:topic_closed")
    end

    it "excludes node types that only exist in an unpublished workflow" do
      graph = build_workflow_graph { |g| g.node "trigger-1", "trigger:topic_closed" }
      Fabricate(:discourse_workflows_workflow, created_by: user, **graph)

      expect(described_class.active_node_types).not_to include("trigger:topic_closed")
    end
  end
end
