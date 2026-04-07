# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Workflow do
  fab!(:user)

  before { SiteSetting.discourse_workflows_enabled = true }

  describe "#trigger_node" do
    it "returns the trigger node" do
      workflow =
        Fabricate(
          :discourse_workflows_workflow,
          created_by: user,
          nodes: [
            {
              "id" => "trigger-1",
              "type" => "trigger:topic_closed",
              "type_version" => "1.0",
              "name" => "Topic Closed",
              "position_index" => 0,
              "configuration" => {
              },
            },
            {
              "id" => "action-1",
              "type" => "action:topic_tags",
              "type_version" => "1.0",
              "name" => "Tag Topic",
              "position_index" => 1,
              "configuration" => {
              },
            },
          ],
          connections: [],
        )

      trigger = workflow.trigger_node
      expect(trigger).to be_a(Hash)
      expect(trigger["id"]).to eq("trigger-1")
      expect(trigger["type"]).to eq("trigger:topic_closed")
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
    it "destroys associated executions" do
      workflow =
        Fabricate(
          :discourse_workflows_workflow,
          created_by: user,
          nodes: [
            {
              "id" => "trigger-1",
              "type" => "trigger:topic_closed",
              "type_version" => "1.0",
              "name" => "Trigger",
              "position_index" => 0,
              "configuration" => {
              },
            },
            {
              "id" => "action-1",
              "type" => "action:topic_tags",
              "type_version" => "1.0",
              "name" => "Action",
              "position_index" => 1,
              "configuration" => {
              },
            },
          ],
          connections: [
            {
              "source_node_id" => "trigger-1",
              "target_node_id" => "action-1",
              "source_output" => "main",
            },
          ],
        )
      Fabricate(:discourse_workflows_execution, workflow: workflow)

      workflow.destroy!

      expect(DiscourseWorkflows::Execution.count).to eq(0)
    end
  end
end
