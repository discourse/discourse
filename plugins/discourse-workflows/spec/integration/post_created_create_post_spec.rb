# frozen_string_literal: true

RSpec.describe "Workflow: post created -> create post" do
  fab!(:admin)
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:topic_owner) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:first_post) { create_post(user: topic_owner, raw: "First post") }
  fab!(:topic) { first_post.topic }

  before do
    Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.clear

    graph =
      build_workflow_graph do |g|
        g.node "trigger-1", "trigger:post_created"
        g.node "action-1",
               "action:post",
               configuration: {
                 "operation" => "create",
                 "topic_id" => "={{ $trigger.topic.id }}",
                 "raw" => "Automated reply",
               }
        g.chain "trigger-1", "action-1"
      end

    Fabricate(
      :discourse_workflows_workflow,
      created_by: admin,
      published: true,
      name: "Reply to new posts",
      **graph,
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
