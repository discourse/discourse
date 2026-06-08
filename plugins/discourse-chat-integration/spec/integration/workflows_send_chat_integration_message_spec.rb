# frozen_string_literal: true

require_relative "../dummy_provider"

RSpec.describe "Workflow: post created -> if author in group -> send to chat-integration channel" do
  include_context "with dummy provider"

  fab!(:admin)
  fab!(:category)
  fab!(:vips, :group)
  fab!(:member) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:outsider) { Fabricate(:user, refresh_auto_groups: true) }

  let(:channel) { DiscourseChatIntegration::Channel.create!(provider: "dummy") }

  before do
    SiteSetting.chat_integration_enabled = true
    SiteSetting.dummy_provider_enabled = true
    SiteSetting.discourse_workflows_enabled = true
    vips.add(member)
    Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.clear

    graph =
      build_workflow_graph do |g|
        g.node "trigger-1", "trigger:post_created", configuration: { "category_id" => category.id }
        g.node "condition-1",
               "condition:if",
               name: "Author in group",
               configuration: {
                 "combinator" => "and",
                 "conditions" => [
                   {
                     "id" => "1",
                     "leftValue" => "={{ $trigger.post.author_group_names }}",
                     "rightValue" => vips.name,
                     "operator" => {
                       "type" => "array",
                       "operation" => "contains",
                     },
                   },
                 ],
               }
        g.node "action-1",
               "action:send_chat_integration_message",
               name: "Notify channel",
               configuration: {
                 "channel_id" => channel.id,
                 "post_id" => "={{ $trigger.post.id }}",
               }
        g.chain "trigger-1", "condition-1"
        g.connect "condition-1", "action-1", output: "true"
      end

    workflow =
      Fabricate(:discourse_workflows_workflow, created_by: admin, name: "Notify VIPs", **graph)
    publish_workflow!(workflow)
  end

  def run_enqueued_workflows
    jobs = Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.dup
    Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.clear
    jobs.each do |job|
      Jobs::DiscourseWorkflows::ExecuteWorkflow.new.execute(job["args"].first.symbolize_keys)
    end
  end

  it "notifies the channel only for posts authored by a group member" do
    PostCreator.create!(
      member,
      title: "Member topic in category",
      raw: "Hello from a VIP",
      category: category.id,
    )
    PostCreator.create!(
      outsider,
      title: "Outsider topic in category",
      raw: "Hello from outside",
      category: category.id,
    )

    run_enqueued_workflows

    expect(provider.sent_to_channel_ids).to contain_exactly(channel.id)
  end
end
