# frozen_string_literal: true

RSpec.describe "Workflow: topic closed -> append tags" do
  fab!(:admin)
  fab!(:user)
  fab!(:topic)
  fab!(:tag) { Fabricate(:tag, name: "resolved") }

  before do
    SiteSetting.discourse_workflows_enabled = true
    SiteSetting.tagging_enabled = true

    DiscourseWorkflows::Registry.reset!
    DiscourseWorkflows::Registry.register_trigger(DiscourseWorkflows::Triggers::TopicClosed::V1)
    DiscourseWorkflows::Registry.register_action(DiscourseWorkflows::Actions::AppendTags::V1)
    DiscourseWorkflows::Registry.register_condition(DiscourseWorkflows::Conditions::IfCondition::V1)

    workflow =
      Fabricate(
        :discourse_workflows_workflow,
        created_by: admin,
        enabled: true,
        name: "Tag closed topics",
      )

    trigger_node =
      Fabricate(
        :discourse_workflows_node,
        workflow: workflow,
        type: "trigger:topic_closed",
        name: "Topic Closed",
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
          "tag_names" => "resolved",
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

  it "tags a topic when it is closed" do
    topic.update_status("closed", true, admin)

    job_data = Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.last
    expect(job_data).to be_present

    Jobs::DiscourseWorkflows::ExecuteWorkflow.new.execute(job_data["args"].first.symbolize_keys)

    expect(topic.reload.tags.map(&:name)).to include("resolved")

    execution = DiscourseWorkflows::Execution.last
    expect(execution.status).to eq("success")
  end

  it "does not trigger when the topic is not closed" do
    topic.update_status("visible", true, admin)

    jobs =
      Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.select do |j|
        j["args"].first["trigger_data"]["topic_id"] == topic.id
      end
    expect(jobs).to be_empty
  end

  it "does not trigger when the topic is reopened" do
    topic.update_status("closed", false, admin)

    jobs =
      Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.select do |j|
        j["args"].first["trigger_data"]["topic_id"] == topic.id
      end
    expect(jobs).to be_empty
  end

  it "does not tag when the workflow is disabled" do
    DiscourseWorkflows::Workflow.update_all(enabled: false)

    topic.update_status("closed", true, admin)

    jobs =
      Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.select do |j|
        j["args"].first["trigger_data"]["topic_id"] == topic.id
      end
    expect(jobs).to be_empty
  end
end
