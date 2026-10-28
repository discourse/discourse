# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::WorkflowTest do
  fab!(:admin)
  fab!(:workflow) do
    graph =
      build_workflow_graph do |builder|
        builder.node "trigger-1", "trigger:manual", name: "Run manually"
        builder.node "topic-1",
                     "action:topic",
                     name: "Get topic",
                     configuration: {
                       "operation" => "get",
                       "topic_id" => 1,
                     }
        builder.node "http-1",
                     "action:http_request",
                     name: "Call API",
                     configuration: {
                       "url" => "https://example.com",
                     }
        builder.chain "trigger-1", "topic-1", "http-1"
      end
    Fabricate(:discourse_workflows_workflow, created_by: admin, **graph)
  end

  def simulation_execution(
    workflow_test,
    result: nil,
    status: :success,
    version_id: workflow.version_id
  )
    execution =
      Fabricate(
        :discourse_workflows_execution,
        workflow:,
        workflow_version_id: version_id,
        status:,
        execution_mode: :simulation,
        workflow_test_id: workflow_test.id,
        workflow_test_digest: workflow_test.definition_digest,
        pin_data_digest: workflow.pin_data_digest,
      )
    data = { "entries" => {}, "context" => {}, "node_contexts" => {}, "run_data" => {} }
    data["simulation"] = { "effects" => [], "test_result" => result } if result
    Fabricate(:discourse_workflows_execution_data, execution:, data:)
    workflow_test.update!(latest_execution_id: execution.id)
    execution
  end

  it "digests the definition without captured outputs or the name" do
    workflow_test = Fabricate(:discourse_workflows_workflow_test, workflow:)
    digest = workflow_test.definition_digest

    workflow_test.update!(name: "Renamed", captured_outputs: { "Get topic:0" => [] })
    expect(workflow_test.definition_digest).to eq(digest)

    workflow_test.update!(
      checks: [DiscourseWorkflows::WorkflowTestChecks.finishes, { effect: "nothing" }],
    )
    expect(workflow_test.definition_digest).not_to eq(digest)
  end

  it "rejects invalid checks and a name over the limit" do
    workflow_test = Fabricate.build(:discourse_workflows_workflow_test, workflow:, name: "x" * 101)
    workflow_test.checks = [{ effect: "chat_message" }]

    expect(workflow_test).not_to be_valid
    expect(workflow_test.errors[:checks]).to eq(
      ["\"chat_message\" is not something a test can check."],
    )
    expect(workflow_test.errors[:name]).to be_present
  end

  it "derives the state from the latest execution and whether it is current" do
    workflow_test = Fabricate(:discourse_workflows_workflow_test, workflow:)
    expect(workflow_test.state).to eq("not_run")

    simulation_execution(workflow_test, status: :running)
    expect(workflow_test.reload.state).to eq("running")

    simulation_execution(
      workflow_test,
      result: {
        "status" => "passed",
        "reason" => nil,
        "checks" => [],
      },
    )
    expect(workflow_test.reload.state).to eq("passed")
    expect(workflow_test.result_current?).to be(true)

    workflow.update_node_pin_data!("Run manually", [{ "json" => { "pinned" => true } }])
    expect(workflow_test.reload.state).to eq("run_again")

    simulation_execution(
      workflow_test,
      result: {
        "status" => "could_not_run",
        "reason" => "nope",
        "checks" => [],
      },
    )
    expect(workflow_test.reload.state).to eq("could_not_run")
    expect(workflow_test.reason).to eq("nope")

    simulation_execution(workflow_test, status: :error)
    workflow_test.latest_execution.update!(error: "enqueue failed")
    expect(workflow_test.reload.state).to eq("could_not_run")
    expect(workflow_test.reason).to eq("enqueue failed")
  end

  it "lists replay steps and the external calls that still need a response" do
    workflow_test = Fabricate(:discourse_workflows_workflow_test, workflow:)

    expect(
      workflow_test.replay_steps.map { |step| step.slice("name", "kind", "needs_response") },
    ).to eq(
      [
        { "name" => "Get topic", "kind" => "lookup", "needs_response" => false },
        { "name" => "Call API", "kind" => "external", "needs_response" => true },
      ],
    )
    expect(workflow_test.steps_needing_response).to eq(["Call API"])

    workflow_test.update!(pasted_responses: { "Call API" => [{ "json" => {} }] })
    expect(workflow_test.steps_needing_response).to eq([])
  end

  it "records captures only for the latest execution and keeps stamped entries" do
    workflow_test = Fabricate(:discourse_workflows_workflow_test, workflow:)
    older = simulation_execution(workflow_test)
    newer = simulation_execution(workflow_test)
    pinned = Time.zone.parse("2026-01-01 00:00:00 UTC")

    workflow_test.record_captures!(
      older,
      { "Get topic:0" => [{ "fingerprint" => "old", "outputs" => [] }] },
      pinned_at: pinned,
    )
    expect(workflow_test.reload.captured_outputs).to eq({})
    expect(workflow_test.captured_at).to be_nil

    workflow_test.record_captures!(
      newer,
      { "Get topic:0" => [{ "fingerprint" => "new", "outputs" => [] }] },
      pinned_at: pinned,
    )
    workflow_test.record_captures!(
      newer,
      { "Get topic:0" => [{ "fingerprint" => "later", "outputs" => [] }] },
      pinned_at: pinned + 1.day,
    )

    expect(workflow_test.reload.captured_outputs).to eq(
      "Get topic:0" => [{ "fingerprint" => "new", "outputs" => [] }],
    )
    expect(workflow_test.captured_at).to eq_time(pinned)
  end

  it "detaches its executions when destroyed" do
    workflow_test = Fabricate(:discourse_workflows_workflow_test, workflow:)
    execution = simulation_execution(workflow_test)

    workflow_test.destroy!

    expect(execution.reload.workflow_test_id).to be_nil
  end
end
