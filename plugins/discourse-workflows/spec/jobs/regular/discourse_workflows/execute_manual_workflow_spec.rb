# frozen_string_literal: true

RSpec.describe Jobs::DiscourseWorkflows::ExecuteManualWorkflow do
  fab!(:admin)

  def pending_execution(workflow:, trigger_node_id: "trigger-1", trigger_data: {})
    DiscourseWorkflows::Execution.create_pending_manual!(
      workflow: workflow,
      trigger_node_id: trigger_node_id,
      trigger_data: trigger_data,
    )
  end

  def execute_job(execution_id, user_id: admin.id)
    described_class.new.execute(execution_id: execution_id, user_id: user_id)
  end

  it "claims and completes a pending execution without creating a duplicate" do
    graph =
      build_workflow_graph do |builder|
        builder.node "trigger-1", "trigger:manual"
        builder.node "log-1", "action:log"
        builder.chain "trigger-1", "log-1"
      end
    workflow = Fabricate(:discourse_workflows_workflow, created_by: admin, **graph)
    execution = pending_execution(workflow: workflow)

    expect do execute_job(execution.id) end.not_to change { DiscourseWorkflows::Execution.count }

    execution.reload
    expect(execution.status).to eq("success")
    expect(execution.started_at).to be_present
    expect(execution.execution_data.steps_array.map { |step| step["node_id"] }).to contain_exactly(
      "trigger-1",
      "log-1",
    )
  end

  it "skips the execution when the plugin is disabled" do
    SiteSetting.enable_discourse_workflows = false
    workflow = Fabricate(:discourse_workflows_workflow, created_by: admin)
    execution = pending_execution(workflow: workflow)

    execute_job(execution.id)

    execution.reload
    expect(execution.status).to eq("skipped")
    expect(execution.finished_at).to be_present
  end

  it "leaves a non-pending execution untouched" do
    workflow = Fabricate(:discourse_workflows_workflow, created_by: admin)
    execution = pending_execution(workflow: workflow)
    execution.update!(status: :running)
    before_updated_at = execution.updated_at

    execute_job(execution.id)

    execution.reload
    expect(execution.status).to eq("running")
    expect(execution.updated_at).to eq_time(before_updated_at)
  end

  it "no-ops when the execution is missing" do
    expect { execute_job(-1) }.not_to change { DiscourseWorkflows::Execution.count }
  end

  it "runs the stored draft snapshot instead of the current or published workflow" do
    published_graph = build_workflow_graph { |builder| builder.node "trigger-1", "trigger:manual" }
    workflow =
      Fabricate(
        :discourse_workflows_workflow,
        created_by: admin,
        published: true,
        **published_graph,
      )
    draft_graph =
      build_workflow_graph do |builder|
        builder.node "trigger-1", "trigger:manual"
        builder.node "draft-log", "action:log"
        builder.chain "trigger-1", "draft-log"
      end
    workflow.update!(nodes: draft_graph[:nodes], connections: draft_graph[:connections])
    execution = pending_execution(workflow: workflow)
    workflow.update!(nodes: published_graph[:nodes], connections: published_graph[:connections])

    execute_job(execution.id)

    expect(execution.reload.execution_data.steps_array.map { |step| step["node_id"] }).to include(
      "draft-log",
    )
  end

  it "records errors on the existing execution" do
    graph = build_workflow_graph { |builder| builder.node "trigger-1", "trigger:manual" }
    workflow = Fabricate(:discourse_workflows_workflow, created_by: admin, **graph)
    execution = pending_execution(workflow: workflow, trigger_node_id: "missing-trigger")

    expect do execute_job(execution.id) end.not_to change { DiscourseWorkflows::Execution.count }

    expect(execution.reload).to have_attributes(status: "error", error: include("missing-trigger"))
  end
end
