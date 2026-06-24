# frozen_string_literal: true

RSpec.describe "Workflow: post moved -> topic tags" do
  fab!(:admin)
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:source_post) { create_post(user: user, raw: "First post") }
  fab!(:source_topic) { source_post.topic }
  fab!(:reply) { create_post(user: user, topic: source_topic, raw: "Moved reply") }
  fab!(:destination_topic, :topic)
  fab!(:tag) { Fabricate(:tag, name: "moved") }

  before do
    SiteSetting.tagging_enabled = true
    Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.clear

    graph =
      build_workflow_graph do |g|
        g.node "trigger-1", "trigger:post_moved"
        g.node "action-1",
               "action:topic_tags",
               configuration: {
                 "operation" => "add",
                 "topic_id" => "={{ $trigger.topic.id }}",
                 "tag_names" => tag.name,
               }
        g.chain "trigger-1", "action-1"
      end

    Fabricate(
      :discourse_workflows_workflow,
      created_by: admin,
      published: true,
      name: "Tag topics with moved posts",
      **graph,
    )
  end

  it "tags the destination topic when a post is moved" do
    source_topic.move_posts(admin, [reply.id], destination_topic_id: destination_topic.id)

    job_data = Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.last
    expect(job_data).to be_present

    trigger_data = job_data["args"].first["trigger_data"]
    expect(trigger_data["post"]).to include(
      "id" => reply.id,
      "raw" => reply.raw,
      "topic_id" => destination_topic.id,
    )
    expect(trigger_data["topic"]).to include("id" => destination_topic.id)
    expect(trigger_data["original_topic"]).to include("id" => source_topic.id)

    Jobs::DiscourseWorkflows::ExecuteWorkflow.new.execute(job_data["args"].first.symbolize_keys)

    expect(destination_topic.reload.tags.map(&:name)).to include("moved")

    execution = DiscourseWorkflows::Execution.last
    expect(execution.status).to eq("success")
  end
end
