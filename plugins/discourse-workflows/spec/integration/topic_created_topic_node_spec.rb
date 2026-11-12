# frozen_string_literal: true

RSpec.describe "Workflow: topic created -> topic create" do
  fab!(:admin)
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:category)

  before do
    Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.clear

    graph =
      build_workflow_graph do |g|
        g.node "trigger-1", "trigger:topic_created"
        g.node "action-1",
               "action:topic",
               configuration: {
                 "operation" => "create",
                 "title" => "Mirror: {{ $trigger.topic_title }}",
                 "raw" => "=Mirrored from topic {{ $trigger.topic_id }}",
                 "category_id" => category.id.to_s,
                 "actor_username" => "system",
               }
        g.chain "trigger-1", "action-1"
      end

    Fabricate(
      :discourse_workflows_workflow,
      created_by: admin,
      published: true,
      name: "Mirror new topics",
      **graph,
    )
  end

  it "creates a mirrored topic without triggering another workflow run" do
    PostCreator.create!(user, title: "Original topic title here", raw: "This is the original body")

    expect(Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.size).to eq(1)

    job_args = Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.last["args"].first.symbolize_keys

    expect { Jobs::DiscourseWorkflows::ExecuteWorkflow.new.execute(job_args) }.to change(
      Topic,
      :count,
    ).by(1)

    mirrored = Topic.last
    expect(mirrored.category_id).to eq(category.id)

    expect(Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.size).to eq(1)
  end
end
