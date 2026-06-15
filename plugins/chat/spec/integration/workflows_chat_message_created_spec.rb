# frozen_string_literal: true

RSpec.describe "Chat message created workflow trigger" do
  fab!(:user)
  fab!(:channel, :chat_channel)
  fab!(:other_channel, :chat_channel)

  before do
    SiteSetting.chat_enabled = true
    SiteSetting.discourse_workflows_enabled = true
  end

  it "enqueues matching workflows when a chat message is created" do
    all_channels_workflow =
      Fabricate(
        :discourse_workflows_workflow,
        created_by: user,
        published: true,
        **build_workflow_graph { |g| g.node "trigger-all", "trigger:chat_message_created" },
      )
    matching_channel_workflow =
      Fabricate(
        :discourse_workflows_workflow,
        created_by: user,
        published: true,
        **build_workflow_graph do |g|
          g.node "trigger-matching",
                 "trigger:chat_message_created",
                 configuration: {
                   "channel_id" => channel.id.to_s,
                 }
        end,
      )
    Fabricate(
      :discourse_workflows_workflow,
      created_by: user,
      published: true,
      **build_workflow_graph do |g|
        g.node "trigger-other",
               "trigger:chat_message_created",
               configuration: {
                 "channel_id" => other_channel.id.to_s,
               }
      end,
    )

    message = Fabricate(:chat_message, chat_channel: channel, user: user)
    DiscourseEvent.trigger(:chat_message_created, message, channel, user)

    jobs =
      Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.select do |job|
        job["args"].first["trigger_node_id"].in?(%w[trigger-all trigger-matching trigger-other])
      end

    expect(jobs.map { |job| job["args"].first["workflow_id"] }).to contain_exactly(
      all_channels_workflow.id,
      matching_channel_workflow.id,
    )
    expect(jobs.map { |job| job["args"].first["trigger_data"] }).to all(
      include("message" => include("id" => message.id), "channel" => include("id" => channel.id)),
    )
  end
end
