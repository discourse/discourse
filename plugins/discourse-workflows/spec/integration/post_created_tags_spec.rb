# frozen_string_literal: true

RSpec.describe "Workflow: post created -> append tags" do
  fab!(:admin)
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:topic_owner) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:first_post) { create_post(user: topic_owner, raw: "First post") }
  fab!(:topic) { first_post.topic }
  fab!(:tag) { Fabricate(:tag, name: "responded") }

  before do
    SiteSetting.discourse_workflows_enabled = true
    SiteSetting.tagging_enabled = true

    Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.clear

    DiscourseWorkflows::Registry.reset!
    DiscourseWorkflows::Registry.register_trigger(DiscourseWorkflows::Triggers::PostCreated)
    DiscourseWorkflows::Registry.register_action(DiscourseWorkflows::Actions::AppendTags)

    workflow =
      Fabricate(
        :discourse_workflows_workflow,
        created_by: admin,
        enabled: true,
        name: "Tag topics with new replies",
      )

    trigger_node =
      Fabricate(
        :discourse_workflows_node,
        workflow: workflow,
        type: "trigger:post_created",
        name: "Post Created",
        position_index: 0,
      )

    action_node =
      Fabricate(
        :discourse_workflows_node,
        workflow: workflow,
        type: "action:append_tags",
        name: "Append Tags",
        position_index: 1,
        configuration: {
          "topic_id" => "={{ trigger.topic_id }}",
          "tag_names" => tag.name,
        },
      )

    Fabricate(
      :discourse_workflows_connection,
      workflow: workflow,
      source_node: trigger_node,
      target_node: action_node,
    )
  end

  after { DiscourseWorkflows::Registry.reset! }

  it "tags a topic when a reply is created" do
    reply =
      PostCreator.create!(
        user,
        topic_id: topic.id,
        raw: "This is a reply",
        reply_to_post_number: topic.first_post.post_number,
      )

    job_data = Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.last
    expect(job_data).to be_present

    trigger_data = job_data["args"].first["trigger_data"]
    expect(trigger_data["post_id"]).to eq(reply.id)
    expect(trigger_data["topic_id"]).to eq(topic.id)
    expect(trigger_data["is_first_post"]).to eq(false)

    Jobs::DiscourseWorkflows::ExecuteWorkflow.new.execute(job_data["args"].first.symbolize_keys)

    expect(topic.reload.tags.map(&:name)).to include("responded")

    execution = DiscourseWorkflows::Execution.last
    expect(execution.status).to eq("success")
  end
end
