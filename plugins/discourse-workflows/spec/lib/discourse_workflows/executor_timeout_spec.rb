# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Executor do
  fab!(:user)

  let(:log_configuration) { {} }
  let(:workflow) do
    graph =
      build_workflow_graph do |g|
        g.node "trigger-1", "trigger:manual"
        g.node "log-1", "action:log", configuration: log_configuration
        g.node "log-2", "action:log"
        g.chain "trigger-1", "log-1", "log-2"
      end
    Fabricate(:discourse_workflows_workflow, created_by: user, published: true, **graph)
  end

  before do
    SiteSetting.discourse_workflows_run_timeout_minutes = 10
    freeze_time
  end

  def run_workflow
    described_class.new(workflow, "trigger-1", {}).run
  end

  def stub_node(node_class, node_id = nil)
    allow_any_instance_of(node_class).to receive(:execute).and_wrap_original do |original, exec_ctx|
      yield exec_ctx if node_id.nil? || exec_ctx.node_id == node_id
      original.call(exec_ctx)
    end
  end

  it "fails the execution instead of running the next node once a node overruns the deadline",
     :aggregate_failures do
    stub_node(DiscourseWorkflows::Nodes::Log::V1, "log-1") { freeze_time(11.minutes.from_now) }

    execution = run_workflow

    expect(execution.reload).to have_attributes(
      status: "error",
      error: "Execution ran for more than 10 minutes without pausing",
    )
    expect(execution.execution_data.find_step(node_id: "log-1")["status"]).to eq("success")
    expect(execution.execution_data.find_step(node_id: "log-2")).to be_nil
  end

  it "fails the execution instead of pausing once a node overruns the deadline" do
    graph =
      build_workflow_graph do |g|
        g.node "trigger-1", "trigger:manual"
        g.node "wait-1", "flow:wait", configuration: { "resume" => "webhook" }
        g.chain "trigger-1", "wait-1"
      end
    wait_workflow =
      Fabricate(:discourse_workflows_workflow, created_by: user, published: true, **graph)
    stub_node(DiscourseWorkflows::Nodes::Wait::V1) { freeze_time(11.minutes.from_now) }

    execution = described_class.new(wait_workflow, "trigger-1", {}).run

    expect(execution.reload).to have_attributes(status: "error", waiting_node_id: nil)
    expect(execution.execution_data.find_step(node_id: "wait-1")["status"]).to eq("error")
  end

  it "does not schedule a resume for an execution that was already failed as stale" do
    graph =
      build_workflow_graph do |g|
        g.node "trigger-1", "trigger:manual"
        g.node "wait-1", "flow:wait", configuration: { "resume" => "webhook" }
        g.chain "trigger-1", "wait-1"
      end
    wait_workflow =
      Fabricate(:discourse_workflows_workflow, created_by: user, published: true, **graph)
    stub_node(DiscourseWorkflows::Nodes::Wait::V1) do |exec_ctx|
      DiscourseWorkflows::Execution.find(exec_ctx.execution_id).update!(status: :error)
    end

    described_class.new(wait_workflow, "trigger-1", {}).run

    expect(Jobs::DiscourseWorkflows::ResumeWaitingExecution.jobs).to be_empty
  end

  context "when the node continues on error" do
    let(:log_configuration) { { "onError" => "continueRegularOutput" } }

    it "does not swallow a timeout raised by the node" do
      stub_node(DiscourseWorkflows::Nodes::Log::V1, "log-1") do
        raise DiscourseWorkflows::Executor::ExecutionTimedOut
      end

      execution = run_workflow

      expect(execution.execution_data.find_step(node_id: "log-1")["status"]).to eq("error")
    end
  end

  it "does not overwrite an execution that was already failed as stale" do
    stub_node(DiscourseWorkflows::Nodes::Log::V1, "log-1") do |exec_ctx|
      DiscourseWorkflows::Execution.find(exec_ctx.execution_id).update!(
        status: :error,
        error: "stale",
      )
    end

    expect(run_workflow.reload).to have_attributes(status: "error", error: "stale")
  end

  it "triggers the error workflow once when the sweep fails a run still stuck in a node" do
    error_graph = build_workflow_graph { |g| g.node "error-1", "trigger:error" }
    error_workflow = Fabricate(:discourse_workflows_workflow, published: true, **error_graph)
    workflow.update!(error_workflow_id: error_workflow.id)
    stub_node(DiscourseWorkflows::Nodes::Log::V1, "log-1") do
      freeze_time(21.minutes.from_now)
      DiscourseWorkflows::Execution::ExpireStale.call
    end

    run_workflow

    error_jobs =
      Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.select do |job|
        job["args"].first["execution_mode"] == "error_mode"
      end
    expect(error_jobs.size).to eq(1)
  end
end
