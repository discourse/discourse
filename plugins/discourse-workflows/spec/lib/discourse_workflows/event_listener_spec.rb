# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::EventListener do
  fab!(:user)
  fab!(:admin)
  fab!(:topic)

  it "enqueues a job when a matching event fires" do
    graph = build_workflow_graph { |g| g.node "trigger-1", "trigger:topic_closed" }
    workflow = Fabricate(:discourse_workflows_workflow, created_by: user, enabled: true, **graph)
    DiscourseWorkflows::WorkflowDependencyIndexer.call(workflow)

    topic.update_status("closed", true, admin)

    job = Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.last
    expect(job).to be_present
    expect(job["args"].first["trigger_node_id"]).to eq("trigger-1")
    expect(job["args"].first["workflow_id"]).to eq(workflow.id)
  end

  it "does not re-enqueue a workflow already in the execution chain" do
    graph = build_workflow_graph { |g| g.node "trigger-1", "trigger:topic_closed" }
    workflow = Fabricate(:discourse_workflows_workflow, created_by: user, enabled: true, **graph)
    DiscourseWorkflows::WorkflowDependencyIndexer.call(workflow)

    db = RailsMultisite::ConnectionManagement.current_db
    DiscourseWorkflows::CurrentExecution.workflow_execution_chains = { db => [workflow.id] }
    topic.update_status("closed", true, admin)
    DiscourseWorkflows::CurrentExecution.reset_all

    jobs =
      Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.select do |j|
        j["args"].first["trigger_node_id"] == "trigger-1"
      end
    expect(jobs).to be_empty
  end

  it "does enqueue a different workflow not in the execution chain" do
    graph = build_workflow_graph { |g| g.node "trigger-1", "trigger:topic_closed" }
    workflow = Fabricate(:discourse_workflows_workflow, created_by: user, enabled: true, **graph)
    other_workflow_id = workflow.id + 1
    DiscourseWorkflows::WorkflowDependencyIndexer.call(workflow)

    db = RailsMultisite::ConnectionManagement.current_db
    DiscourseWorkflows::CurrentExecution.workflow_execution_chains = { db => [other_workflow_id] }
    topic.update_status("closed", true, admin)
    DiscourseWorkflows::CurrentExecution.reset_all

    job =
      Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.find do |j|
        j["args"].first["trigger_node_id"] == "trigger-1"
      end
    expect(job).to be_present
    expect(job["args"].first["workflow_execution_chain"]).to eq([other_workflow_id])
  end

  it "does not enqueue when plugin is disabled" do
    SiteSetting.discourse_workflows_enabled = false

    graph = build_workflow_graph { |g| g.node "trigger-1", "trigger:topic_closed" }
    workflow = Fabricate(:discourse_workflows_workflow, created_by: user, enabled: true, **graph)
    DiscourseWorkflows::WorkflowDependencyIndexer.call(workflow)

    topic.update_status("closed", true, admin)

    jobs =
      Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.select do |j|
        j["args"].first["trigger_node_id"] == "trigger-1"
      end
    expect(jobs).to be_empty
  end
end
