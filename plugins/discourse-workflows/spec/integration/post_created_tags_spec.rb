# frozen_string_literal: true

RSpec.describe "Workflow: post created -> topic tags" do
  fab!(:admin)
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:topic_owner) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:first_post) { create_post(user: topic_owner, raw: "First post") }
  fab!(:topic) { first_post.topic }
  fab!(:tag) { Fabricate(:tag, name: "responded") }

  before do
    SiteSetting.tagging_enabled = true

    Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.clear

    graph =
      build_workflow_graph do |g|
        g.node "trigger-1", "trigger:post_created"
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
      name: "Tag topics with new replies",
      **graph,
    )
  end

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
    expect(trigger_data["post"]).to include("id" => reply.id, "raw" => reply.raw)
    expect(trigger_data["topic"]).to include("id" => topic.id)

    Jobs::DiscourseWorkflows::ExecuteWorkflow.new.execute(job_data["args"].first.symbolize_keys)

    expect(topic.reload.tags.map(&:name)).to include("responded")

    execution = DiscourseWorkflows::Execution.last
    expect(execution.status).to eq("success")
  end
end
