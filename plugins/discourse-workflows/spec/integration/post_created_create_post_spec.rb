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

    Fabricate(
      :discourse_workflows_workflow,
      created_by: admin,
      enabled: true,
      name: "Reply to new posts",
      nodes: [
        {
          "id" => "trigger-1",
          "type" => "trigger:post_created",
          "type_version" => "1.0",
          "name" => "Post Created",
          "position" => {
            "x" => 0,
            "y" => 0,
          },
          "position_index" => 0,
          "configuration" => {
          },
        },
        {
          "id" => "action-1",
          "type" => "action:create_post",
          "type_version" => "1.0",
          "name" => "Create Post",
          "position" => {
            "x" => 200,
            "y" => 0,
          },
          "position_index" => 1,
          "configuration" => {
            "topic_id" => "={{ trigger.topic.id }}",
            "raw" => "Automated reply",
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
  end

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
