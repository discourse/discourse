# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Execution::CheckSchedules do
  describe ".call" do
    subject(:result) { described_class.call }

    fab!(:user)

    def schedule_config(*rules)
      { "rule" => { "interval" => rules } }
    end

    def create_schedule_workflow(configuration:, settings: {})
      graph =
        build_workflow_graph do |g|
          g.node "trigger-1", "trigger:schedule", configuration: configuration
        end
      Fabricate(
        :discourse_workflows_workflow,
        published: true,
        created_by: user,
        settings: settings,
        **graph,
      )
    end

    context "when plugin is disabled" do
      before { SiteSetting.enable_discourse_workflows = false }

      it { is_expected.to fail_a_policy(:workflows_enabled) }
    end

    it "enqueues matching minute rules through the trigger context" do
      freeze_time Time.utc(2026, 3, 18, 9, 5)
      workflow =
        create_schedule_workflow(
          configuration: schedule_config({ "field" => "minutes", "minutesInterval" => 5 }),
        )

      expect { result }.to change { Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.size }.by(1)

      job = Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.last
      expect(job["args"].first["workflow_id"]).to eq(workflow.id)
      expect(job["args"].first["workflow_version_id"]).to eq(workflow.active_version_id)
    end

    it "normalizes scheduler ticks to the current minute" do
      freeze_time Time.utc(2026, 3, 18, 9, 5, 12)
      create_schedule_workflow(
        configuration: schedule_config({ "field" => "minutes", "minutesInterval" => 5 }),
      )

      expect { result }.to change { Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.size }.by(1)

      trigger_data =
        Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.last["args"].first["trigger_data"]
      expect(trigger_data).to include("hour" => "09", "minute" => "05", "second" => "00")
    end

    it "does not enqueue when a cron rule does not match" do
      freeze_time Time.utc(2026, 3, 18, 10, 0)
      create_schedule_workflow(
        configuration:
          schedule_config({ "field" => "cronExpression", "expression" => "0 9 * * *" }),
      )

      expect { result }.not_to change { Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.size }
    end

    it "evaluates rules in the workflow timezone" do
      freeze_time Time.utc(2026, 3, 18, 8, 0)
      create_schedule_workflow(
        settings: {
          "timezone" => "Europe/Paris",
        },
        configuration:
          schedule_config(
            {
              "field" => "days",
              "daysInterval" => 1,
              "triggerAtHour" => 9,
              "triggerAtMinute" => 0,
            },
          ),
      )

      expect { result }.to change { Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.size }.by(1)

      trigger_data =
        Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.last["args"].first["trigger_data"]
      expect(trigger_data).to include(
        "hour" => "09",
        "minute" => "00",
        "timezone" => "Europe/Paris (UTC+01:00)",
      )
      expect(trigger_data["timestamp"]).to end_with("+01:00")
    end

    it "supports multiple independent rules" do
      freeze_time Time.utc(2026, 3, 18, 12, 0)
      create_schedule_workflow(
        configuration:
          schedule_config(
            {
              "field" => "days",
              "daysInterval" => 1,
              "triggerAtHour" => 9,
              "triggerAtMinute" => 0,
            },
            { "field" => "cronExpression", "expression" => "0 12 * * *" },
          ),
      )

      expect { result }.to change { Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.size }.by(1)
    end

    it "fires overlapping rules on the same node independently" do
      freeze_time Time.utc(2026, 3, 18, 9, 0)
      create_schedule_workflow(
        configuration:
          schedule_config(
            { "field" => "minutes", "minutesInterval" => 1 },
            { "field" => "cronExpression", "expression" => "0 9 * * *" },
          ),
      )

      expect { result }.to change { Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.size }.by(2)
    end

    it "deduplicates repeated ticks for the same scheduled time" do
      freeze_time Time.utc(2026, 3, 18, 9, 0)
      create_schedule_workflow(
        configuration:
          schedule_config({ "field" => "cronExpression", "expression" => "0 9 * * *" }),
      )

      described_class.call
      expect(Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.size).to eq(1)

      described_class.call
      expect(Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.size).to eq(1)
    end

    it "fires again for a new matching minute" do
      freeze_time Time.utc(2026, 3, 18, 9, 0)
      create_schedule_workflow(
        configuration:
          schedule_config({ "field" => "cronExpression", "expression" => "0 * * * *" }),
      )

      described_class.call
      expect(Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.size).to eq(1)

      freeze_time Time.utc(2026, 3, 18, 10, 0)
      described_class.call
      expect(Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.size).to eq(2)
    end

    it "uses recurrence state for multi-day intervals" do
      workflow =
        create_schedule_workflow(
          configuration:
            schedule_config(
              {
                "field" => "days",
                "daysInterval" => 3,
                "triggerAtHour" => 9,
                "triggerAtMinute" => 0,
              },
            ),
        )

      freeze_time Time.utc(2026, 3, 18, 9, 0)
      described_class.call
      expect(Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.size).to eq(1)

      freeze_time Time.utc(2026, 3, 19, 9, 0)
      described_class.call
      expect(Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.size).to eq(1)

      freeze_time Time.utc(2026, 3, 21, 9, 0)
      described_class.call
      expect(Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.size).to eq(2)
      expect(workflow.reload.static_data).to include(
        "node:Trigger-1" => {
          "recurrenceRules" => be_present,
        },
      )
    end

    it "does not enqueue unpublished workflows" do
      freeze_time Time.utc(2026, 3, 18, 9, 0)
      workflow =
        create_schedule_workflow(
          configuration:
            schedule_config({ "field" => "cronExpression", "expression" => "0 9 * * *" }),
        )
      unpublish_workflow!(workflow)

      expect { result }.not_to change { Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.size }
    end
  end
end
