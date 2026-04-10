# frozen_string_literal: true

RSpec.describe "Workflow: topic closed -> topic tags" do
  fab!(:admin)
  fab!(:topic)
  fab!(:tag) { Fabricate(:tag, name: "resolved") }

  before do
    SiteSetting.discourse_workflows_enabled = true
    SiteSetting.tagging_enabled = true

    graph =
      build_workflow_graph do |g|
        g.node "trigger-1", "trigger:topic_closed"
        g.node "action-1",
               "action:topic_tags",
               configuration: {
                 "operation" => "add",
                 "topic_id" => "={{ trigger.topic.id }}",
                 "tag_names" => "resolved",
               }
        g.chain "trigger-1", "action-1"
      end

    Fabricate(
      :discourse_workflows_workflow,
      created_by: admin,
      enabled: true,
      name: "Tag closed topics",
      **graph,
    )
  end

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
        j["args"].first["trigger_data"].dig("topic", "id") == topic.id
      end
    expect(jobs).to be_empty
  end

  it "does not trigger when the topic is reopened" do
    topic.update_status("closed", false, admin)

    jobs =
      Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.select do |j|
        j["args"].first["trigger_data"].dig("topic", "id") == topic.id
      end
    expect(jobs).to be_empty
  end

  it "does not tag when the workflow is disabled" do
    DiscourseWorkflows::Workflow.update_all(enabled: false)

    topic.update_status("closed", true, admin)

    jobs =
      Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.select do |j|
        j["args"].first["trigger_data"].dig("topic", "id") == topic.id
      end
    expect(jobs).to be_empty
  end
end
