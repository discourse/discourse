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

  describe "#node_has_reachable_downstream_of_type?" do
    it "returns true when the target type is a direct downstream" do
      workflow =
        Fabricate(
          :discourse_workflows_workflow,
          created_by: user,
          nodes: [
            {
              "id" => "trigger-1",
              "type" => "trigger:form",
              "type_version" => "1.0",
              "name" => "Form",
              "position_index" => 0,
              "configuration" => {
              },
            },
            {
              "id" => "action-1",
              "type" => "action:form",
              "type_version" => "1.0",
              "name" => "Second Form",
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

      expect(workflow.node_has_reachable_downstream_of_type?("trigger-1", "action:form")).to be(
        true,
      )
    end

    it "returns true when the target type is separated by intermediate nodes" do
      workflow =
        Fabricate(
          :discourse_workflows_workflow,
          created_by: user,
          nodes: [
            {
              "id" => "trigger-1",
              "type" => "trigger:form",
              "type_version" => "1.0",
              "name" => "Form",
              "position_index" => 0,
              "configuration" => {
              },
            },
            {
              "id" => "action-1",
              "type" => "action:send_message",
              "type_version" => "1.0",
              "name" => "Send Message",
              "position_index" => 1,
              "configuration" => {
              },
            },
            {
              "id" => "action-2",
              "type" => "action:form",
              "type_version" => "1.0",
              "name" => "Second Form",
              "position_index" => 2,
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
            {
              "source_node_id" => "action-1",
              "target_node_id" => "action-2",
              "source_output" => "main",
            },
          ],
        )

      expect(workflow.node_has_reachable_downstream_of_type?("trigger-1", "action:form")).to be(
        true,
      )
    end

    it "returns false when no downstream node matches" do
      workflow =
        Fabricate(
          :discourse_workflows_workflow,
          created_by: user,
          nodes: [
            {
              "id" => "trigger-1",
              "type" => "trigger:form",
              "type_version" => "1.0",
              "name" => "Form",
              "position_index" => 0,
              "configuration" => {
              },
            },
            {
              "id" => "action-1",
              "type" => "action:send_message",
              "type_version" => "1.0",
              "name" => "Send Message",
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

      expect(workflow.node_has_reachable_downstream_of_type?("trigger-1", "action:form")).to be(
        false,
      )
    end

    it "handles cycles without infinite looping" do
      workflow =
        Fabricate(
          :discourse_workflows_workflow,
          created_by: user,
          nodes: [
            {
              "id" => "trigger-1",
              "type" => "trigger:form",
              "type_version" => "1.0",
              "name" => "Form",
              "position_index" => 0,
              "configuration" => {
              },
            },
            {
              "id" => "condition-1",
              "type" => "condition:boolean",
              "type_version" => "1.0",
              "name" => "Check",
              "position_index" => 1,
              "configuration" => {
              },
            },
          ],
          connections: [
            {
              "source_node_id" => "trigger-1",
              "target_node_id" => "condition-1",
              "source_output" => "main",
            },
            {
              "source_node_id" => "condition-1",
              "target_node_id" => "trigger-1",
              "source_output" => "main",
            },
          ],
        )

      expect(workflow.node_has_reachable_downstream_of_type?("trigger-1", "action:form")).to be(
        false,
      )
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
