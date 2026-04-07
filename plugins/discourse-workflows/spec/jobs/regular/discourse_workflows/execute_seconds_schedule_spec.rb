# frozen_string_literal: true

require "rails_helper"

RSpec.describe Jobs::DiscourseWorkflows::ExecuteSecondsSchedule do
  fab!(:user)

  before { SiteSetting.discourse_workflows_enabled = true }

  def create_seconds_workflow(seconds:)
    workflow =
      Fabricate(
        :discourse_workflows_workflow,
        enabled: true,
        created_by: user,
        nodes: [
          {
            "id" => "trigger-1",
            "type" => "trigger:schedule",
            "type_version" => "1.0",
            "name" => "Schedule",
            "position" => {
              "x" => 0,
              "y" => 0,
            },
            "position_index" => 0,
            "configuration" => {
              "rules" => [{ "interval" => "seconds", "seconds_between_triggers" => seconds }],
            },
          },
        ],
        connections: [],
      )

    rule = { "interval" => "seconds", "seconds_between_triggers" => seconds }
    DiscourseWorkflows::ScheduleRule.start_seconds_chain!(workflow, "trigger-1", 0, rule)
    token = workflow.reload.node_static_data("trigger-1").dig("seconds_tokens", "0")

    # Clear the job enqueued by start_seconds_chain! so tests start clean
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
