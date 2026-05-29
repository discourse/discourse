# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Executor::ErrorWorkflowTrigger do
  fab!(:user)

  def build_handler(workflow, steps, execution: nil, execution_mode: :normal)
    execution ||=
      Fabricate(
        :discourse_workflows_error_execution,
        workflow: workflow,
        execution_mode: execution_mode,
      )

    described_class.new(workflow, steps, execution: execution, execution_mode: execution_mode)
  end

  def build_steps(last_failed_step: nil)
    return [] if last_failed_step.nil?

    [DiscourseWorkflows::Executor::Step.from_h(last_failed_step.merge("status" => "error"))]
  end

  def build_error_workflow
    graph = build_workflow_graph { |g| g.node "error-trigger-1", "trigger:error" }
    Fabricate(:discourse_workflows_workflow, created_by: user, published: true, **graph)
  end

  def build_workflow_with_error_handler(error_wf: nil, error_wf_published: true, handler_opts: {})
    if error_wf.nil? && error_wf_published
      error_wf = build_error_workflow
    elsif error_wf.nil?
      error_wf = build_error_workflow
      unpublish_workflow!(error_wf)
    end

    workflow = Fabricate(:discourse_workflows_workflow, created_by: user, published: true)
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
      expect(job["args"].first["workflow_version_id"]).to eq(error_wf.active_version_id)
      expect(job["args"].first["execution_mode"]).to eq("error_mode")
    end

    it "allows an error workflow to use itself when the failed execution is normal" do
      graph = build_workflow_graph { |g| g.node "error-trigger-1", "trigger:error" }
      workflow =
        Fabricate(:discourse_workflows_workflow, created_by: user, published: true, **graph)
      workflow.update_columns(error_workflow_id: workflow.id)
      handler = build_handler(workflow, build_steps)

      handler.trigger_error_workflow(StandardError.new("boom"))

      job = Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.last
      expect(job["args"].first["workflow_id"]).to eq(workflow.id)
      expect(job["args"].first["trigger_node_id"]).to eq("error-trigger-1")
    end

    it "does not retrigger the same workflow when already running in error mode" do
      graph = build_workflow_graph { |g| g.node "error-trigger-1", "trigger:error" }
      workflow =
        Fabricate(:discourse_workflows_workflow, created_by: user, published: true, **graph)
      workflow.update_columns(error_workflow_id: workflow.id)
      handler = build_handler(workflow, build_steps, execution_mode: :error_mode)

      trigger_and_expect_no_jobs(handler)
    end

    it "runs a different configured error workflow when already running in error mode" do
      error_wf, handler =
        build_workflow_with_error_handler(handler_opts: { execution_mode: :error_mode })

      handler.trigger_error_workflow(StandardError.new("boom"))

      job = Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.last
      expect(job["args"].first["workflow_id"]).to eq(error_wf.id)
    end

    it "enqueues an error workflow execution for manual executions" do
      error_wf, handler =
        build_workflow_with_error_handler(handler_opts: { execution_mode: :manual })

      handler.trigger_error_workflow(StandardError.new("boom"))

      job = Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.last
      expect(job["args"].first["workflow_id"]).to eq(error_wf.id)
    end

    it "uses the failing workflow as its error workflow when it has an Error trigger and no configured error workflow" do
      graph = build_workflow_graph { |g| g.node "error-trigger-1", "trigger:error" }
      workflow =
        Fabricate(:discourse_workflows_workflow, created_by: user, published: true, **graph)
      handler = build_handler(workflow, build_steps)

      handler.trigger_error_workflow(StandardError.new("boom"))

      job = Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.last
      expect(job["args"].first["workflow_id"]).to eq(workflow.id)
      expect(job["args"].first["trigger_node_id"]).to eq("error-trigger-1")
    end

    it "does not trigger when no error workflow is configured" do
      workflow = Fabricate(:discourse_workflows_workflow, created_by: user, published: true)
      handler = build_handler(workflow, build_steps)
      trigger_and_expect_no_jobs(handler)
    end

    it "does not trigger when error workflow is unpublished" do
      _, handler = build_workflow_with_error_handler(error_wf_published: false)
      trigger_and_expect_no_jobs(handler)
    end

    it "does not trigger when error workflow has no error trigger node" do
      error_wf = Fabricate(:discourse_workflows_workflow, created_by: user, published: true)
      workflow = Fabricate(:discourse_workflows_workflow, created_by: user, published: true)
      workflow.update!(error_workflow_id: error_wf.id)
      handler = build_handler(workflow, build_steps)
      trigger_and_expect_no_jobs(handler)
    end

    it "includes compatible execution error data" do
      failed_step = { "node_id" => "1", "node_name" => "My Node", "status" => "error" }
      _, handler =
        build_workflow_with_error_handler(handler_opts: { last_failed_step: failed_step })

      handler.trigger_error_workflow(StandardError.new("something broke"))

      trigger_data =
        Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.last["args"].first["trigger_data"]
      expect(trigger_data["workflow"]).to include("id" => be_present, "name" => be_present)
      expect(trigger_data["execution"]).to include(
        "id" => be_present,
        "url" => include("/admin/plugins/discourse-workflows/workflows/"),
        "retryOf" => nil,
        "error" => include("message" => "something broke", "name" => "StandardError"),
        "lastNodeExecuted" => "My Node",
        "mode" => "trigger",
      )
    end

    it "exposes execution.error with null id/url when no execution record is available" do
      error_wf = build_error_workflow
      workflow = Fabricate(:discourse_workflows_workflow, created_by: user, published: true)
      workflow.update!(error_workflow_id: error_wf.id)
      handler = described_class.new(workflow, build_steps, execution: nil, execution_mode: :normal)

      handler.trigger_error_workflow(StandardError.new("trigger broke"))

      trigger_data =
        Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.last["args"].first["trigger_data"]
      expect(trigger_data["execution"]).to include(
        "id" => nil,
        "url" => nil,
        "error" => include("message" => "trigger broke", "name" => "StandardError"),
        "lastNodeExecuted" => nil,
        "mode" => "trigger",
      )
      expect(trigger_data["workflow"]).to include("id" => workflow.id.to_s, "name" => workflow.name)
    end

    it "truncates long error messages" do
      _, handler = build_workflow_with_error_handler

      handler.trigger_error_workflow(StandardError.new("x" * 2000))

      trigger_data =
        Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.last["args"].first["trigger_data"]
      expect(trigger_data.dig("execution", "error", "message").length).to be <= 1003
    end
  end
end
