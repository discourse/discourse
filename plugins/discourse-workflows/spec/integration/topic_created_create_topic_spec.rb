# frozen_string_literal: true

RSpec.describe "Workflow: topic created -> create topic" do
  fab!(:admin)
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:category)

  before do
    SiteSetting.discourse_workflows_enabled = true

    Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.clear

    DiscourseWorkflows::Registry.reset!
    DiscourseWorkflows::Registry.register_trigger(DiscourseWorkflows::Triggers::TopicCreated)
    DiscourseWorkflows::Registry.register_action(DiscourseWorkflows::Actions::CreateTopic)

    workflow =
      Fabricate(
        :discourse_workflows_workflow,
        created_by: admin,
        enabled: true,
        name: "Mirror new topics",
      )

    trigger_node =
      Fabricate(
        :discourse_workflows_node,
        workflow: workflow,
        type: "trigger:topic_created",
        name: "Topic Created",
        position_index: 0,
      )

    action_node =
      Fabricate(
        :discourse_workflows_node,
        workflow: workflow,
        type: "action:create_topic",
        name: "Create Topic",
        position_index: 1,
        configuration: {
          "title" => "Mirror: {{ trigger.topic_title }}",
          "raw" => "=Mirrored from topic {{ trigger.topic_id }}",
          "category_id" => category.id.to_s,
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
