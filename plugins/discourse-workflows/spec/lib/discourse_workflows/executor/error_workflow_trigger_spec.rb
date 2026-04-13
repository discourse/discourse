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

  def build_workflow_with_error_handler(error_wf: nil, error_wf_enabled: true, handler_opts: {})
    if error_wf.nil? && error_wf_enabled
      error_wf = build_error_workflow
    elsif error_wf.nil?
      error_wf = build_error_workflow
      error_wf.update!(enabled: false)
    end

    workflow = Fabricate(:discourse_workflows_workflow, created_by: user, enabled: true)
    workflow.update!(error_workflow_id: error_wf.id)
    steps = build_steps(**handler_opts.slice(:last_failed_step))
    handler = build_handler(workflow, steps, **handler_opts.except(:last_failed_step))

    [error_wf, handler]
  end

  def trigger_and_expect_no_jobs(handler)
    handler.trigger_error_workflow(StandardError.new("boom"))
    expect(Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs).to be_empty
  end

  describe "#trigger_error_workflow" do
    it "enqueues an error workflow execution" do
      error_wf, handler = build_workflow_with_error_handler

      handler.trigger_error_workflow(StandardError.new("boom"))

      job = Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.last
      expect(job).to be_present
      expect(job["args"].first["workflow_id"]).to eq(error_wf.id)
      expect(job["args"].first["execution_mode"]).to eq("error_mode")
      expect(job["args"].first["error_depth"]).to eq(1)
    end

    it "does not trigger when error_depth >= MAX_ERROR_DEPTH" do
      _, handler = build_workflow_with_error_handler(handler_opts: { error_depth: 3 })
      trigger_and_expect_no_jobs(handler)
    end

    it "does not trigger in error_mode execution" do
      _, handler = build_workflow_with_error_handler(handler_opts: { execution_mode: :error_mode })
      trigger_and_expect_no_jobs(handler)
    end

    it "does not trigger when no error workflow is configured" do
      workflow = Fabricate(:discourse_workflows_workflow, created_by: user, enabled: true)
      handler = build_handler(workflow, build_steps)
      trigger_and_expect_no_jobs(handler)
    end

    it "does not trigger when error workflow is disabled" do
      _, handler = build_workflow_with_error_handler(error_wf_enabled: false)
      trigger_and_expect_no_jobs(handler)
    end

    it "does not trigger when error workflow has no error trigger node" do
      error_wf = Fabricate(:discourse_workflows_workflow, created_by: user, enabled: true)
      workflow = Fabricate(:discourse_workflows_workflow, created_by: user, enabled: true)
      workflow.update!(error_workflow_id: error_wf.id)
      handler = build_handler(workflow, build_steps)
      trigger_and_expect_no_jobs(handler)
    end

    it "includes error data with failed node name" do
      failed_step = { "node_id" => "1", "node_name" => "My Node", "status" => "error" }
      _, handler =
        build_workflow_with_error_handler(handler_opts: { last_failed_step: failed_step })

      handler.trigger_error_workflow(StandardError.new("something broke"))

      trigger_data =
        Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.last["args"].first["trigger_data"]
      expect(trigger_data["error_message"]).to eq("something broke")
      expect(trigger_data["failed_node_name"]).to eq("My Node")
    end

    it "truncates long error messages" do
      _, handler = build_workflow_with_error_handler

      handler.trigger_error_workflow(StandardError.new("x" * 2000))

      trigger_data =
        Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.last["args"].first["trigger_data"]
      expect(trigger_data["error_message"].length).to be <= 1003
    end
  end
end
