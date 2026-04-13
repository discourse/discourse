# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Workflow do
  fab!(:user)

  describe "#trigger_node" do
    it "returns the trigger node" do
      graph =
        build_workflow_graph do |g|
          g.node "trigger-1", "trigger:topic_closed"
          g.node "action-1", "action:topic_tags"
        end
      workflow = Fabricate(:discourse_workflows_workflow, created_by: user, **graph)

      trigger = workflow.trigger_node
      expect(trigger).to be_a(Hash)
      expect(trigger["id"]).to eq("trigger-1")
      expect(trigger["type"]).to eq("trigger:topic_closed")
    end
  end

  describe "#node_has_reachable_downstream_of_type?" do
    it "returns true when the target type is a direct downstream" do
      graph =
        build_workflow_graph do |g|
          g.node "trigger-1", "trigger:form"
          g.node "action-1", "action:form"
          g.chain "trigger-1", "action-1"
        end
      workflow = Fabricate(:discourse_workflows_workflow, created_by: user, **graph)

      expect(workflow.node_has_reachable_downstream_of_type?("trigger-1", "action:form")).to be(
        true,
      )
    end

    it "returns true when the target type is separated by intermediate nodes" do
      graph =
        build_workflow_graph do |g|
          g.node "trigger-1", "trigger:form"
          g.node "action-1", "action:send_message"
          g.node "action-2", "action:form"
          g.chain "trigger-1", "action-1", "action-2"
        end
      workflow = Fabricate(:discourse_workflows_workflow, created_by: user, **graph)

      expect(workflow.node_has_reachable_downstream_of_type?("trigger-1", "action:form")).to be(
        true,
      )
    end

    it "returns false when no downstream node matches" do
      graph =
        build_workflow_graph do |g|
          g.node "trigger-1", "trigger:form"
          g.node "action-1", "action:send_message"
          g.chain "trigger-1", "action-1"
        end
      workflow = Fabricate(:discourse_workflows_workflow, created_by: user, **graph)

      expect(workflow.node_has_reachable_downstream_of_type?("trigger-1", "action:form")).to be(
        false,
      )
    end

    it "handles cycles without infinite looping" do
      graph =
        build_workflow_graph do |g|
          g.node "trigger-1", "trigger:form"
          g.node "condition-1", "condition:boolean"
          g.connect "trigger-1", "condition-1"
          g.connect "condition-1", "trigger-1"
        end
      workflow = Fabricate(:discourse_workflows_workflow, created_by: user, **graph)

      expect(workflow.node_has_reachable_downstream_of_type?("trigger-1", "action:form")).to be(
        false,
      )
    end
  end

  describe "dependent destroy" do
    it "destroys associated executions" do
      graph =
        build_workflow_graph do |g|
          g.node "trigger-1", "trigger:topic_closed"
          g.node "action-1", "action:topic_tags"
          g.chain "trigger-1", "action-1"
        end
      workflow = Fabricate(:discourse_workflows_workflow, created_by: user, **graph)
      Fabricate(:discourse_workflows_execution, workflow: workflow)

      workflow.destroy!

      expect(DiscourseWorkflows::Execution.count).to eq(0)
    end
  end
end
