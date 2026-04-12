# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Executor do
  fab!(:user)
  fab!(:channel, :chat_channel)

  before { SiteSetting.chat_enabled = true }

  describe "pause on wait request" do
    it "pauses execution and sends a chat message with approval buttons" do
      graph =
        build_workflow_graph do |g|
          g.node "trigger-1", "trigger:manual"
          g.node "wait-1",
                 "action:chat_approval",
                 configuration: {
                   "message" => "Please approve",
                   "channel_id" => channel.id.to_s,
                 }
          g.node "after-1",
                 "action:set_fields",
                 name: "After Approval",
                 configuration: {
                   "mode" => "json",
                   "include_input" => true,
                   "json" => '{"done": "true"}',
                 }
          g.chain "trigger-1", "wait-1", "after-1"
        end
      workflow = Fabricate(:discourse_workflows_workflow, created_by: user, enabled: true, **graph)

      execution = described_class.new(workflow, "trigger-1", {}).run

      expect(execution).to have_attributes(
        status: "waiting",
        waiting_node_id: "wait-1",
        finished_at: nil,
      )

      waiting_step = execution.execution_data.find_step(node_id: "wait-1")
      expect(waiting_step["status"]).to eq("waiting")

      expect(execution.execution_data.context_data).not_to have_key("After Approval")

      chat_message = Chat::Message.where(chat_channel_id: channel.id).last
      expect(chat_message).to be_present
      expect(chat_message).to have_attributes(message: "Please approve", blocks: be_present)
      expect(chat_message.blocks.first["elements"].size).to eq(2)

      approve_action_id = chat_message.blocks.first["elements"].first["action_id"]
      expect(approve_action_id).to start_with("dwf:")
    end

    it "stores timeout config when timeout_minutes is set" do
      graph =
        build_workflow_graph do |g|
          g.node "trigger-1", "trigger:manual"
          g.node "wait-1",
                 "action:chat_approval",
                 configuration: {
                   "message" => "Approve?",
                   "channel_id" => channel.id.to_s,
                   "timeout_minutes" => "60",
                   "timeout_action" => "fail",
                 }
          g.chain "trigger-1", "wait-1"
        end
      workflow = Fabricate(:discourse_workflows_workflow, created_by: user, enabled: true, **graph)

      freeze_time do
        execution = described_class.new(workflow, "trigger-1", {}).run

        expect(execution).to have_attributes(
          status: "waiting",
          waiting_until: eq_time(60.minutes.from_now),
        )
        expect(execution.waiting_config).to include("timeout_action" => "fail")
      end
    end
  end

  describe ".resume" do
    fab!(:completed_execution) { Fabricate(:discourse_workflows_execution, status: :success) }

    it "resumes a waiting execution with approved response" do
      graph =
        build_workflow_graph do |g|
          g.node "trigger-1", "trigger:manual"
          g.node "wait-1",
                 "action:chat_approval",
                 configuration: {
                   "message" => "Approve?",
                   "channel_id" => channel.id.to_s,
                 }
          g.node "after-1",
                 "action:set_fields",
                 name: "After",
                 configuration: {
                   "mode" => "json",
                   "include_input" => true,
                   "json" => '{"done": "true"}',
                 }
          g.chain "trigger-1", "wait-1", "after-1"
        end
      workflow = Fabricate(:discourse_workflows_workflow, created_by: user, enabled: true, **graph)

      execution = described_class.new(workflow, "trigger-1", {}).run
      expect(execution.status).to eq("waiting")

      response_items = [{ "json" => { "approved" => true } }]
      resumed = DiscourseWorkflows::Executor.resume(execution.reload, response_items)

      expect(resumed).to have_attributes(
        status: "success",
        finished_at: be_present,
        waiting_node_id: nil,
      )

      after_output = resumed.execution_data.context_data["After"]
      expect(after_output).to be_an(Array)
      expect(after_output.first["json"]).to include("approved" => true, "done" => "true")
    end

    it "raises when attempting to resume a non-waiting execution" do
      response_items = [{ "json" => { "approved" => true } }]

      expect {
        DiscourseWorkflows::Executor.resume(completed_execution, response_items)
      }.to raise_error(ArgumentError, /Cannot resume execution/)
    end
  end
end
