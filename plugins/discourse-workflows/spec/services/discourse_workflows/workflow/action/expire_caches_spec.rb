# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Workflow::Action::ExpireCaches do
  describe ".call" do
    subject(:result) { described_class.call }

    it "clears workflow dependency caches" do
      graph = build_workflow_graph { |builder| builder.node "trigger-1", "trigger:manual" }
      workflow = Fabricate(:discourse_workflows_workflow, published: true, **graph)
      expect(DiscourseWorkflows::WorkflowDependency.active_node_types).to contain_exactly(
        "trigger:manual",
      )

      DiscourseWorkflows::WorkflowDependency.where(workflow: workflow).delete_all
      expect(DiscourseWorkflows::WorkflowDependency.active_node_types).to contain_exactly(
        "trigger:manual",
      )

      result

      expect(DiscourseWorkflows::WorkflowDependency.active_node_types).to be_empty
    end

    it "does not clear the site cache" do
      Site.expects(:clear_cache).never
      DiscourseWorkflows::WorkflowDependency.stubs(:clear_cache!)

      result
    end
  end
end
