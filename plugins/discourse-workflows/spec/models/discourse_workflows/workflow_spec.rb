# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Workflow do
  fab!(:user)

  before { SiteSetting.discourse_workflows_enabled = true }

  describe "validations" do
    it "requires a name" do
      workflow = described_class.new(created_by: user)
      expect(workflow.valid?).to eq(false)
      expect(workflow.errors[:name]).to be_present
    end

    it "enforces name length" do
      workflow = described_class.new(name: "a" * 101, created_by: user)
      expect(workflow.valid?).to eq(false)
    end
  end

  describe "#trigger_node" do
    it "returns the trigger node" do
      workflow = Fabricate(:discourse_workflows_workflow, created_by: user)
      trigger =
        Fabricate(
          :discourse_workflows_node,
          workflow: workflow,
          type: "trigger:topic_closed",
          name: "Topic Closed",
        )
      Fabricate(
        :discourse_workflows_node,
        workflow: workflow,
        type: "action:append_tags",
        name: "Tag Topic",
      )

      expect(workflow.trigger_node).to eq(trigger)
    end
  end

  describe ".enabled" do
    it "returns only enabled workflows" do
      Fabricate(:discourse_workflows_workflow, created_by: user, enabled: true)
      Fabricate(:discourse_workflows_workflow, created_by: user, enabled: false)

      expect(described_class.enabled.count).to eq(1)
    end
  end

  describe "dependent destroy" do
    it "destroys associated nodes, connections, and executions" do
      workflow = Fabricate(:discourse_workflows_workflow, created_by: user)
      node1 =
        Fabricate(
          :discourse_workflows_node,
          workflow: workflow,
          type: "trigger:topic_closed",
          name: "Trigger",
        )
      node2 =
        Fabricate(
          :discourse_workflows_node,
          workflow: workflow,
          type: "action:append_tags",
          name: "Action",
        )
      Fabricate(
        :discourse_workflows_connection,
        workflow: workflow,
        source_node: node1,
        target_node: node2,
      )
      Fabricate(:discourse_workflows_execution, workflow: workflow)

      workflow.destroy!

      expect(DiscourseWorkflows::Node.count).to eq(0)
      expect(DiscourseWorkflows::Connection.count).to eq(0)
      expect(DiscourseWorkflows::Execution.count).to eq(0)
    end
  end
end
