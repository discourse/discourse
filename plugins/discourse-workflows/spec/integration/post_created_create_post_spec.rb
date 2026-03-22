# frozen_string_literal: true

RSpec.describe "Workflow: post created -> create post" do
  fab!(:admin)
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:topic_owner) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:first_post) { create_post(user: topic_owner, raw: "First post") }
  fab!(:topic) { first_post.topic }

  before do
    SiteSetting.discourse_workflows_enabled = true

    Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.clear

    DiscourseWorkflows::Registry.reset!
    DiscourseWorkflows::Registry.register_trigger(DiscourseWorkflows::Triggers::PostCreated)
    DiscourseWorkflows::Registry.register_action(DiscourseWorkflows::Actions::CreatePost)

    workflow =
      Fabricate(
        :discourse_workflows_workflow,
        created_by: admin,
        enabled: true,
        name: "Reply to new posts",
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
        type: "action:create_post",
        name: "Create Post",
        position_index: 1,
        configuration: {
          "topic_id" => "={{ trigger.topic_id }}",
          "raw" => "Automated reply",
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

  it "creates one automated reply without enqueueing another workflow run" do
    PostCreator.create!(
      user,
      topic_id: topic.id,
      raw: "User reply",
      reply_to_post_number: first_post.post_number,
    )

    expect(Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.size).to eq(1)

    job_args = Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.last["args"].first.symbolize_keys

    expect do Jobs::DiscourseWorkflows::ExecuteWorkflow.new.execute(job_args) end.to change {
      Post.where(topic: topic, raw: "Automated reply").count
    }.by(1)

    expect(Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.size).to eq(1)
  end
end
