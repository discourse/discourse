# frozen_string_literal: true

RSpec.describe "Workflow: topic created -> create topic" do
  fab!(:admin)
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:category)

  before do
    SiteSetting.discourse_workflows_enabled = true

    Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.clear

    Fabricate(
      :discourse_workflows_workflow,
      created_by: admin,
      enabled: true,
      name: "Mirror new topics",
      nodes: [
        {
          "id" => "trigger-1",
          "type" => "trigger:topic_created",
          "type_version" => "1.0",
          "name" => "Topic Created",
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
          "type" => "action:create_topic",
          "type_version" => "1.0",
          "name" => "Create Topic",
          "position" => {
            "x" => 200,
            "y" => 0,
          },
          "position_index" => 1,
          "configuration" => {
            "title" => "Mirror: {{ trigger.topic_title }}",
            "raw" => "=Mirrored from topic {{ trigger.topic_id }}",
            "category_id" => category.id.to_s,
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
