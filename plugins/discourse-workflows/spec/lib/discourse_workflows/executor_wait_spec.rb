# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Executor do
  fab!(:user)
  fab!(:channel, :chat_channel)

  before do
    SiteSetting.discourse_workflows_enabled = true
    SiteSetting.chat_enabled = true
    DiscourseWorkflows::Registry.reset!
    DiscourseWorkflows::Registry.register_trigger(DiscourseWorkflows::Triggers::Manual)
    DiscourseWorkflows::Registry.register_action(DiscourseWorkflows::Actions::SetFields)
    DiscourseWorkflows::Registry.register_action(DiscourseWorkflows::Actions::WaitForApproval)
  end

  after { DiscourseWorkflows::Registry.reset! }

  describe "pause on WaitForHuman" do
    it "pauses execution and sends a chat message with approval buttons" do
      workflow = Fabricate(:discourse_workflows_workflow, created_by: user, enabled: true)

      trigger_node =
        Fabricate(
          :discourse_workflows_node,
          workflow: workflow,
          type: "trigger:manual",
          name: "Manual",
          position_index: 0,
        )

      wait_node =
        Fabricate(
          :discourse_workflows_node,
          workflow: workflow,
          type: "action:wait_for_approval",
          name: "Wait for Approval",
          position_index: 1,
          configuration: {
            "message" => "Please approve",
            "channel_id" => channel.id.to_s,
          },
        )

      after_node =
        Fabricate(
          :discourse_workflows_node,
          workflow: workflow,
          type: "action:set_fields",
          name: "After Approval",
          position_index: 2,
          configuration: {
            "mode" => "json",
            "include_input" => true,
            "json" => '{"done": "true"}',
          },
        )

      Fabricate(
        :discourse_workflows_connection,
        workflow: workflow,
        source_node: trigger_node,
        target_node: wait_node,
      )

      Fabricate(
        :discourse_workflows_connection,
        workflow: workflow,
        source_node: wait_node,
        target_node: after_node,
      )

      execution = DiscourseWorkflows::Executor.new(trigger_node, {}).run

      expect(execution.status).to eq("waiting")
      expect(execution.waiting_node_id).to eq(wait_node.id)
      expect(execution.context).to have_key("trigger")
      expect(execution.finished_at).to be_nil

      waiting_step = execution.steps.find_by(node_id: wait_node.id)
      expect(waiting_step.status).to eq("waiting")

      expect(execution.context).not_to have_key("After Approval")

      chat_message = Chat::Message.where(chat_channel_id: channel.id).last
      expect(chat_message).to be_present
      expect(chat_message.message).to eq("Please approve")
      expect(chat_message.blocks).to be_present
      expect(chat_message.blocks.first["elements"].size).to eq(2)

      approve_action_id = chat_message.blocks.first["elements"].first["action_id"]
      expect(approve_action_id).to start_with("dwf:")
    end

    it "stores timeout config when timeout_minutes is set" do
      workflow = Fabricate(:discourse_workflows_workflow, created_by: user, enabled: true)

      trigger_node =
        Fabricate(
          :discourse_workflows_node,
          workflow: workflow,
          type: "trigger:manual",
          name: "Manual",
          position_index: 0,
        )

      wait_node =
        Fabricate(
          :discourse_workflows_node,
          workflow: workflow,
          type: "action:wait_for_approval",
          name: "Wait",
          position_index: 1,
          configuration: {
            "message" => "Approve?",
            "channel_id" => channel.id.to_s,
            "timeout_minutes" => "60",
            "timeout_action" => "fail",
          },
        )

      Fabricate(
        :discourse_workflows_connection,
        workflow: workflow,
        source_node: trigger_node,
        target_node: wait_node,
      )

      freeze_time do
        execution = DiscourseWorkflows::Executor.new(trigger_node, {}).run

        expect(execution.status).to eq("waiting")
        expect(execution.waiting_until).to eq_time(60.minutes.from_now)
        expect(execution.waiting_config["timeout_action"]).to eq("fail")
      end
    end
  end

  describe ".resume" do
    it "resumes a waiting execution with approved response" do
      workflow = Fabricate(:discourse_workflows_workflow, created_by: user, enabled: true)

      trigger_node =
        Fabricate(
          :discourse_workflows_node,
          workflow: workflow,
          type: "trigger:manual",
          name: "Manual",
          position_index: 0,
        )

      wait_node =
        Fabricate(
          :discourse_workflows_node,
          workflow: workflow,
          type: "action:wait_for_approval",
          name: "Wait",
          position_index: 1,
          configuration: {
            "message" => "Approve?",
            "channel_id" => channel.id.to_s,
          },
        )

      after_node =
        Fabricate(
          :discourse_workflows_node,
          workflow: workflow,
          type: "action:set_fields",
          name: "After",
          position_index: 2,
          configuration: {
            "mode" => "json",
            "include_input" => true,
            "json" => '{"done": "true"}',
          },
        )

      Fabricate(
        :discourse_workflows_connection,
        workflow: workflow,
        source_node: trigger_node,
        target_node: wait_node,
      )
      Fabricate(
        :discourse_workflows_connection,
        workflow: workflow,
        source_node: wait_node,
        target_node: after_node,
      )

      execution = DiscourseWorkflows::Executor.new(trigger_node, {}).run
      expect(execution.status).to eq("waiting")

      response_items = [{ "json" => { "approved" => true } }]
      resumed = DiscourseWorkflows::Executor.resume(execution.reload, response_items)

      expect(resumed.status).to eq("success")
      expect(resumed.finished_at).to be_present
      expect(resumed.waiting_node_id).to be_nil

      after_output = resumed.context["After"]
      expect(after_output).to be_an(Array)
      expect(after_output.first["json"]["approved"]).to eq(true)
      expect(after_output.first["json"]["done"]).to eq("true")
    end

    it "does not resume a non-waiting execution" do
      execution = Fabricate(:discourse_workflows_execution, status: :success)
      response_items = [{ "json" => { "approved" => true } }]

      result = DiscourseWorkflows::Executor.resume(execution, response_items)
      expect(result).to be_nil
    end
  end
end
