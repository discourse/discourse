# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Executor do
  fab!(:admin)
  fab!(:topic_owner) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:first_post) { create_post(user: topic_owner, raw: "First post") }
  fab!(:topic) { first_post.topic }

  before do
    SiteSetting.discourse_workflows_enabled = true
    DiscourseWorkflows::Registry.reset!
    DiscourseWorkflows::Registry.register_trigger(DiscourseWorkflows::Triggers::Manual)
    DiscourseWorkflows::Registry.register_action(DiscourseWorkflows::Actions::CreatePost)
  end

  after { DiscourseWorkflows::Registry.reset! }

  it "creates a post from trigger data" do
    workflow = Fabricate(:discourse_workflows_workflow, created_by: admin, enabled: true)

    trigger_node =
      Fabricate(
        :discourse_workflows_node,
        workflow: workflow,
        type: "trigger:manual",
        name: "Manual Trigger",
        position_index: 0,
      )

    action_node =
      Fabricate(
        :discourse_workflows_node,
        workflow: workflow,
        type: "action:create_post",
        name: "Create Post",
        position_index: 1,
        configuration: {
          "topic_id" => "={{ trigger.topic_id }}",
          "raw" => "={{ trigger.raw }}",
          "reply_to_post_number" => "={{ trigger.reply_to_post_number }}",
          "user_id" => "={{ trigger.user_id }}",
        },
      )

    Fabricate(
      :discourse_workflows_connection,
      workflow: workflow,
      source_node: trigger_node,
      target_node: action_node,
    )

    trigger_data = {
      topic_id: topic.id,
      raw: "Generated reply",
      reply_to_post_number: first_post.post_number,
      user_id: admin.id,
    }

    execution = described_class.new(trigger_node, trigger_data).run
    reply = topic.posts.order(:id).last

    expect(execution.status).to eq("success")
    expect(reply.raw).to eq("Generated reply")
    expect(reply.reply_to_post_number).to eq(first_post.post_number)
    expect(reply.user_id).to eq(admin.id)
    expect(execution.context["Create Post"].first["json"]).to include(
      "post_id" => reply.id,
      "topic_id" => topic.id,
      "post_raw" => "Generated reply",
      "user_id" => admin.id,
    )
  end
end
