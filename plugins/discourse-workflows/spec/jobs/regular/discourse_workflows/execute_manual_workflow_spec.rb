# frozen_string_literal: true

RSpec.describe Jobs::DiscourseWorkflows::ExecuteManualWorkflow do
  fab!(:admin)

  it "claims and completes a pending execution without creating a duplicate" do
    graph =
      build_workflow_graph do |builder|
        builder.node "trigger-1", "trigger:manual"
        builder.node "log-1", "action:log"
        builder.chain "trigger-1", "log-1"
      end
    workflow = Fabricate(:discourse_workflows_workflow, created_by: admin, **graph)
    execution =
      DiscourseWorkflows::Execution.create_pending_manual!(
        workflow:,
        trigger_node_id: "trigger-1",
        trigger_data: {
        },
      )

    expect do
      described_class.new.execute(execution_id: execution.id, user_id: admin.id)
    end.not_to change { DiscourseWorkflows::Execution.count }

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
    execution =
      DiscourseWorkflows::Execution.create_pending_manual!(
        workflow:,
        trigger_node_id: "trigger-1",
        trigger_data: {
        },
      )

    messages =
      MessageBus.track_publish(
        DiscourseWorkflows::ExecutionProgressPublisher.execution_channel(execution.id),
      ) { described_class.new.execute(execution_id: execution.id, user_id: admin.id) }

    execution.reload
    expect(execution.status).to eq("skipped")
    expect(execution.finished_at).to be_present
    expect(messages.one?).to eq(true)
    expect(messages.first.data).to include(type: "execution_progress", refresh: true)
    expect(messages.first.data[:execution]).to include(id: execution.id, status: "skipped")
  end

  it "leaves a non-pending execution untouched" do
    workflow = Fabricate(:discourse_workflows_workflow, created_by: admin)
    execution =
      DiscourseWorkflows::Execution.create_pending_manual!(
        workflow:,
        trigger_node_id: "trigger-1",
        trigger_data: {
        },
      )
    execution.update!(status: :running)
    before_updated_at = execution.updated_at

    described_class.new.execute(execution_id: execution.id, user_id: admin.id)

    execution.reload
    expect(execution.status).to eq("running")
    expect(execution.updated_at).to eq_time(before_updated_at)
  end

  it "no-ops when the execution is missing" do
    expect { described_class.new.execute(execution_id: -1, user_id: admin.id) }.not_to change {
      DiscourseWorkflows::Execution.count
    }
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
    execution =
      DiscourseWorkflows::Execution.create_pending_manual!(
        workflow:,
        trigger_node_id: "trigger-1",
        trigger_data: {
        },
      )
    workflow.update!(nodes: published_graph[:nodes], connections: published_graph[:connections])

    described_class.new.execute(execution_id: execution.id, user_id: admin.id)

    expect(execution.reload.execution_data.steps_array.map { |step| step["node_id"] }).to include(
      "draft-log",
    )
  end

  it "records errors on the existing execution" do
    graph = build_workflow_graph { |builder| builder.node "trigger-1", "trigger:manual" }
    workflow = Fabricate(:discourse_workflows_workflow, created_by: admin, **graph)
    execution =
      DiscourseWorkflows::Execution.create_pending_manual!(
        workflow:,
        trigger_node_id: "missing-trigger",
        trigger_data: {
        },
      )

    expect do
      described_class.new.execute(execution_id: execution.id, user_id: admin.id)
    end.not_to change { DiscourseWorkflows::Execution.count }

    expect(execution.reload).to have_attributes(status: "error", error: include("missing-trigger"))
  end
end
