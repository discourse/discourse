# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Executor::ErrorWorkflowTrigger do
  fab!(:user)

  def build_handler(workflow, steps, error_depth: 0, execution_mode: :normal)
    described_class.new(workflow, steps, error_depth: error_depth, execution_mode: execution_mode)
  end

  def build_steps(last_failed_step: nil)
    return [] if last_failed_step.nil?

    [DiscourseWorkflows::Executor::Step.from_h(last_failed_step.merge("status" => "error"))]
  end

  def build_error_workflow
    graph = build_workflow_graph { |g| g.node "error-trigger-1", "trigger:error" }
    Fabricate(:discourse_workflows_workflow, created_by: user, enabled: true, **graph)
  end

  describe "#trigger_error_workflow" do
    it "enqueues an error workflow execution" do
      error_wf = build_error_workflow
      workflow = Fabricate(:discourse_workflows_workflow, created_by: user, enabled: true)
      workflow.update!(error_workflow_id: error_wf.id)
      steps = build_steps
      handler = build_handler(workflow, steps)

      handler.trigger_error_workflow(StandardError.new("boom"))

      job = Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.last
      expect(job).to be_present
      expect(job["args"].first["workflow_id"]).to eq(error_wf.id)
      expect(job["args"].first["execution_mode"]).to eq("error_mode")
      expect(job["args"].first["error_depth"]).to eq(1)
    end

    it "does not trigger when error_depth >= MAX_ERROR_DEPTH" do
      error_wf = build_error_workflow
      workflow = Fabricate(:discourse_workflows_workflow, created_by: user, enabled: true)
      workflow.update!(error_workflow_id: error_wf.id)
      steps = build_steps
      handler = build_handler(workflow, steps, error_depth: 3)

      handler.trigger_error_workflow(StandardError.new("boom"))

      expect(Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs).to be_empty
    end

    it "does not trigger in error_mode execution" do
      error_wf = build_error_workflow
      workflow = Fabricate(:discourse_workflows_workflow, created_by: user, enabled: true)
      workflow.update!(error_workflow_id: error_wf.id)
      steps = build_steps
      handler = build_handler(workflow, steps, execution_mode: :error_mode)

      handler.trigger_error_workflow(StandardError.new("boom"))

      expect(Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs).to be_empty
    end

    it "does not trigger when no error workflow is configured" do
      workflow = Fabricate(:discourse_workflows_workflow, created_by: user, enabled: true)
      steps = build_steps
      handler = build_handler(workflow, steps)

      handler.trigger_error_workflow(StandardError.new("boom"))

      expect(Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs).to be_empty
    end

    it "does not trigger when error workflow is disabled" do
      error_wf = build_error_workflow
      error_wf.update!(enabled: false)
      workflow = Fabricate(:discourse_workflows_workflow, created_by: user, enabled: true)
      workflow.update!(error_workflow_id: error_wf.id)
      steps = build_steps
      handler = build_handler(workflow, steps)

      handler.trigger_error_workflow(StandardError.new("boom"))

      expect(Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs).to be_empty
    end

    it "does not trigger when error workflow has no error trigger node" do
      error_wf = Fabricate(:discourse_workflows_workflow, created_by: user, enabled: true)
      workflow = Fabricate(:discourse_workflows_workflow, created_by: user, enabled: true)
      workflow.update!(error_workflow_id: error_wf.id)
      steps = build_steps
      handler = build_handler(workflow, steps)

      handler.trigger_error_workflow(StandardError.new("boom"))

      expect(Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs).to be_empty
    end

    it "includes error data with failed node name" do
      error_wf = build_error_workflow
      workflow = Fabricate(:discourse_workflows_workflow, created_by: user, enabled: true)
      workflow.update!(error_workflow_id: error_wf.id)
      failed_step = { "node_id" => "1", "node_name" => "My Node", "status" => "error" }
      steps = build_steps(last_failed_step: failed_step)
      handler = build_handler(workflow, steps)

      handler.trigger_error_workflow(StandardError.new("something broke"))

      trigger_data =
        Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.last["args"].first["trigger_data"]
      expect(trigger_data["error_message"]).to eq("something broke")
      expect(trigger_data["failed_node_name"]).to eq("My Node")
    end

    it "truncates long error messages" do
      error_wf = build_error_workflow
      workflow = Fabricate(:discourse_workflows_workflow, created_by: user, enabled: true)
      workflow.update!(error_workflow_id: error_wf.id)
      steps = build_steps
      handler = build_handler(workflow, steps)

      handler.trigger_error_workflow(StandardError.new("x" * 2000))

      trigger_data =
        Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.last["args"].first["trigger_data"]
      expect(trigger_data["error_message"].length).to be <= 1003
    end
  end
end
