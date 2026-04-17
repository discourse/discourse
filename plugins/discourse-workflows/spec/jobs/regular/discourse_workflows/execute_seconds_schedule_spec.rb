# frozen_string_literal: true

RSpec.describe Jobs::DiscourseWorkflows::ExecuteSecondsSchedule do
  fab!(:user)

  def create_seconds_workflow(seconds:)
    graph =
      build_workflow_graph do |g|
        g.node "trigger-1",
               "trigger:schedule",
               configuration: {
                 "rules" => [{ "interval" => "seconds", "seconds_between_triggers" => seconds }],
               }
      end
    workflow = Fabricate(:discourse_workflows_workflow, enabled: true, created_by: user, **graph)

    rule = { "interval" => "seconds", "seconds_between_triggers" => seconds }
    DiscourseWorkflows::ScheduleRule.start_seconds_chain!(workflow, "trigger-1", 0, rule)
    token = workflow.reload.node_static_data("trigger-1").dig("seconds_tokens", "0")

    Jobs::DiscourseWorkflows::ExecuteSecondsSchedule.jobs.clear

    [workflow, token]
  end

  it "executes the workflow and reschedules" do
    workflow, token = create_seconds_workflow(seconds: 10)

    described_class.new.execute(
      workflow_id: workflow.id,
      trigger_node_id: "trigger-1",
      rule_index: 0,
      token: token,
    )

    expect(Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.size).to eq(1)
    expect(Jobs::DiscourseWorkflows::ExecuteSecondsSchedule.jobs.size).to eq(1)
  end

  it "does not execute when workflow is disabled" do
    workflow, token = create_seconds_workflow(seconds: 10)
    workflow.update!(enabled: false)

    described_class.new.execute(
      workflow_id: workflow.id,
      trigger_node_id: "trigger-1",
      rule_index: 0,
      token: token,
    )

    expect(Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.size).to eq(0)
    expect(Jobs::DiscourseWorkflows::ExecuteSecondsSchedule.jobs.size).to eq(0)
  end

  it "does not execute with stale token" do
    workflow, _token = create_seconds_workflow(seconds: 10)

    described_class.new.execute(
      workflow_id: workflow.id,
      trigger_node_id: "trigger-1",
      rule_index: 0,
      token: "stale-token",
    )

    expect(Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.size).to eq(0)
    expect(Jobs::DiscourseWorkflows::ExecuteSecondsSchedule.jobs.size).to eq(0)
  end

  it "does not execute or reschedule when the plugin is disabled" do
    workflow, token = create_seconds_workflow(seconds: 10)
    SiteSetting.discourse_workflows_enabled = false

    described_class.new.execute(
      workflow_id: workflow.id,
      trigger_node_id: "trigger-1",
      rule_index: 0,
      token: token,
    )

    expect(Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.size).to eq(0)
    expect(Jobs::DiscourseWorkflows::ExecuteSecondsSchedule.jobs.size).to eq(0)
  end

  it "stops chain when rule changes to non-seconds" do
    workflow, token = create_seconds_workflow(seconds: 10)

    workflow.update!(
      nodes: [
        workflow.parsed_nodes.first.merge(
          "configuration" => {
            "rules" => [{ "interval" => "minutes", "minutes_between_triggers" => 5 }],
          },
        ),
      ],
    )

    described_class.new.execute(
      workflow_id: workflow.id,
      trigger_node_id: "trigger-1",
      rule_index: 0,
      token: token,
    )

    expect(Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.size).to eq(0)
    expect(Jobs::DiscourseWorkflows::ExecuteSecondsSchedule.jobs.size).to eq(0)
  end
end
