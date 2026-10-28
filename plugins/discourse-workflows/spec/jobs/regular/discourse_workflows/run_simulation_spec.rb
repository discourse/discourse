# frozen_string_literal: true

RSpec.describe Jobs::DiscourseWorkflows::RunSimulation do
  fab!(:admin)
  fab!(:recipient, :user)
  fab!(:topic)
  fab!(:workflow) do
    graph =
      build_workflow_graph do |builder|
        builder.node "trigger-1", "trigger:manual", name: "Run manually"
        builder.node "topic-1",
                     "action:topic",
                     name: "Get topic",
                     configuration: {
                       "operation" => "get",
                       "topic_id" => topic.id,
                       "actor_username" => admin.username,
                     }
        builder.node "pm-1",
                     "action:send_personal_message",
                     name: "Send PM",
                     configuration: {
                       "recipient_usernames" => [recipient.username],
                       "title" => "Hello there",
                       "raw" => "Simulated message body",
                     }
        builder.chain "trigger-1", "topic-1", "pm-1"
      end
    Fabricate(:discourse_workflows_workflow, created_by: admin, published: true, **graph)
  end

  def run_test(workflow_test)
    execution =
      DiscourseWorkflows::WorkflowTest::Action::EnqueueRun.call(workflow_test:, user: admin)
    described_class.new.execute(execution_id: execution.id, user_id: admin.id)
    execution.reload
  end

  it "evaluates the checks, stores the result and captures lookups on the first run" do
    workflow_test =
      Fabricate(
        :discourse_workflows_workflow_test,
        workflow:,
        checks: [
          { effect: "finishes" },
          {
            effect: "personal_message",
            conditions: [{ field: "recipient", value: recipient.username }],
          },
        ],
      )

    execution = nil
    expect { execution = run_test(workflow_test) }.not_to change { Topic.count }

    expect(execution).to be_success
    expect(execution.execution_data.test_result).to include("status" => "passed")
    expect(execution.execution_data.simulation["effects"].map { |effect| effect["type"] }).to eq(
      ["personal_message"],
    )

    workflow_test.reload
    expect(workflow_test.state).to eq("passed")
    expect(workflow_test.captured_at).to eq_time(
      Time.zone.parse(execution.execution_data.simulation["pinned_at"]),
    )
    expect(workflow_test.captured_outputs.keys).to eq(["Get topic:0"])
    expect(workflow_test.captured_outputs["Get topic:0"].first["fingerprint"]).to be_present
  end

  it "replays captured lookups and the pinned clock on later runs" do
    workflow_test =
      Fabricate(:discourse_workflows_workflow_test, workflow:, checks: [{ effect: "finishes" }])
    first = run_test(workflow_test)
    topic.update!(title: "Changed since capture")
    freeze_time(2.days.from_now)

    second = run_test(workflow_test)

    output =
      second.execution_data.run_data["Get topic"].first["outputs"].first["items"].first["json"]
    expect(output["topic"]["title"]).not_to eq("Changed since capture")
    expect(second.execution_data.simulation["pinned_at"]).to eq(
      first.execution_data.simulation["pinned_at"],
    )
  end

  it "reports a failed check with a plain reason" do
    workflow_test =
      Fabricate(
        :discourse_workflows_workflow_test,
        workflow:,
        checks: [
          {
            effect: "personal_message",
            conditions: [{ field: "recipient", value: "someone-else" }],
          },
        ],
      )

    execution = run_test(workflow_test)

    expect(workflow_test.reload.state).to eq("failed")
    expect(workflow_test.reason).to include(
      "Expected a personal message, but the closest match was",
    )
    expect(execution.execution_data.test_result["checks"].first).to include("status" => "failed")
  end

  it "does not let an older run write captures after a newer run was enqueued" do
    workflow_test =
      Fabricate(:discourse_workflows_workflow_test, workflow:, checks: [{ effect: "finishes" }])
    older = DiscourseWorkflows::WorkflowTest::Action::EnqueueRun.call(workflow_test:, user: admin)
    newer = DiscourseWorkflows::WorkflowTest::Action::EnqueueRun.call(workflow_test:, user: admin)

    described_class.new.execute(execution_id: older.id, user_id: admin.id)

    expect(older.reload).to be_success
    expect(workflow_test.reload.captured_outputs).to eq({})
    expect(workflow_test.latest_execution_id).to eq(newer.id)
  end

  it "runs a preview without a test and records effects only" do
    execution =
      DiscourseWorkflows::Execution.create_pending_simulation!(
        workflow:,
        trigger_node_id: "trigger-1",
        trigger_data: {
        },
      )

    described_class.new.execute(execution_id: execution.id, user_id: admin.id)

    execution.reload
    expect(execution).to be_success
    expect(execution.execution_data.test_result).to be_nil
    expect(execution.execution_data.simulation["effects"].first["fields"]).to include(
      "recipient" => recipient.username,
    )
  end

  it "ignores executions that are not pending simulations" do
    execution =
      DiscourseWorkflows::Execution.create_pending_manual!(
        workflow:,
        trigger_node_id: "trigger-1",
        trigger_data: {
        },
      )

    described_class.new.execute(execution_id: execution.id, user_id: admin.id)

    expect(execution.reload).to be_pending
  end
end
