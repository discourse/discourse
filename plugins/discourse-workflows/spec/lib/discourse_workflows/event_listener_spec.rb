# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::EventListener do
  fab!(:user)
  fab!(:admin)
  fab!(:topic)
  fab!(:tag)

  before do
    SiteSetting.discourse_workflows_enabled = true
    SiteSetting.tagging_enabled = true
  end

  it "enqueues a job when a matching event fires" do
    workflow = Fabricate(:discourse_workflows_workflow, created_by: user, enabled: true)

    Fabricate(
      :discourse_workflows_node,
      workflow: workflow,
      type: "trigger:topic_closed",
      name: "Topic Closed",
    )

    topic.update_status("closed", true, admin)

    job = Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.last
    expect(job).to be_present
    expect(job["args"].first["trigger_node_id"]).to be_present
  end

  it "does not enqueue when plugin is disabled" do
    SiteSetting.discourse_workflows_enabled = false

    workflow = Fabricate(:discourse_workflows_workflow, created_by: user, enabled: true)

    node =
      Fabricate(
        :discourse_workflows_node,
        workflow: workflow,
        type: "trigger:topic_closed",
        name: "Topic Closed",
      )

    topic.update_status("closed", true, admin)

    jobs =
      Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.select do |j|
        j["args"].first["trigger_node_id"] == node.id
      end
    expect(jobs).to be_empty
  end
end
