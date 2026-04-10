# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Execution::CheckSchedules do
  describe ".call" do
    subject(:result) { described_class.call }

    fab!(:user)

    before { SiteSetting.discourse_workflows_enabled = true }

    def create_schedule_workflow(configuration:)
      graph =
        build_workflow_graph do |g|
          g.node "trigger-1", "trigger:schedule", configuration: configuration
        end
      Fabricate(:discourse_workflows_workflow, enabled: true, created_by: user, **graph)
    end

    context "when plugin is disabled" do
      before { SiteSetting.discourse_workflows_enabled = false }

      it { is_expected.to fail_a_policy(:workflows_enabled) }
    end

    context "with minutes interval" do
      it "enqueues when minutes match" do
        freeze_time Time.utc(2026, 3, 18, 9, 5)
        workflow =
          create_schedule_workflow(
            configuration: {
              "rules" => [{ "interval" => "minutes", "minutes_between_triggers" => 5 }],
            },
          )

        expect { result }.to change { Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.size }.by(1)

        job = Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.last
        expect(job["args"].first["workflow_id"]).to eq(workflow.id)
      end
    end

    context "with hours interval" do
      it "enqueues at the specified minute of matching hours" do
        freeze_time Time.utc(2026, 3, 18, 10, 30)
        create_schedule_workflow(
          configuration: {
            "rules" => [
              { "interval" => "hours", "hours_between_triggers" => 2, "trigger_at_minute" => 30 },
            ],
          },
        )

        expect { result }.to change { Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.size }.by(1)
      end

      it "does not enqueue at wrong minute" do
        freeze_time Time.utc(2026, 3, 18, 10, 0)
        create_schedule_workflow(
          configuration: {
            "rules" => [
              { "interval" => "hours", "hours_between_triggers" => 2, "trigger_at_minute" => 30 },
            ],
          },
        )

        expect { result }.not_to change { Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.size }
      end
    end

    context "with days interval" do
      it "enqueues at the specified hour and minute" do
        freeze_time Time.utc(2026, 3, 18, 9, 0)
        create_schedule_workflow(
          configuration: {
            "rules" => [
              {
                "interval" => "days",
                "days_between_triggers" => 1,
                "trigger_at_hour" => 9,
                "trigger_at_minute" => 0,
              },
            ],
          },
        )

        expect { result }.to change { Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.size }.by(1)
      end
    end

    context "with weeks interval" do
      it "enqueues on matching weekday at specified time" do
        freeze_time Time.utc(2026, 3, 16, 8, 0) # Monday
        create_schedule_workflow(
          configuration: {
            "rules" => [
              {
                "interval" => "weeks",
                "weeks_between_triggers" => 1,
                "trigger_on_weekdays" => [1],
                "trigger_at_hour" => 8,
                "trigger_at_minute" => 0,
              },
            ],
          },
        )

        expect { result }.to change { Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.size }.by(1)
      end

      it "does not enqueue on non-matching weekday" do
        freeze_time Time.utc(2026, 3, 17, 8, 0) # Tuesday
        create_schedule_workflow(
          configuration: {
            "rules" => [
              {
                "interval" => "weeks",
                "weeks_between_triggers" => 1,
                "trigger_on_weekdays" => [1],
                "trigger_at_hour" => 8,
                "trigger_at_minute" => 0,
              },
            ],
          },
        )

        expect { result }.not_to change { Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.size }
      end
    end

    context "with months interval" do
      it "enqueues on matching day of month" do
        freeze_time Time.utc(2026, 3, 15, 12, 0)
        create_schedule_workflow(
          configuration: {
            "rules" => [
              {
                "interval" => "months",
                "months_between_triggers" => 1,
                "trigger_at_day_of_month" => 15,
                "trigger_at_hour" => 12,
                "trigger_at_minute" => 0,
              },
            ],
          },
        )

        expect { result }.to change { Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.size }.by(1)
      end
    end

    context "with cron rule" do
      it "enqueues when cron matches" do
        freeze_time Time.utc(2026, 3, 18, 9, 0)
        workflow =
          create_schedule_workflow(
            configuration: {
              "rules" => [{ "interval" => "cron", "cron" => "0 9 * * *" }],
            },
          )

        expect { result }.to change { Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.size }.by(1)

        job = Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.last
        expect(job["args"].first["trigger_node_id"]).to eq("trigger-1")
        expect(job["args"].first["workflow_id"]).to eq(workflow.id)
      end

      it "does not enqueue when cron does not match" do
        freeze_time Time.utc(2026, 3, 18, 10, 0)
        create_schedule_workflow(
          configuration: {
            "rules" => [{ "interval" => "cron", "cron" => "0 9 * * *" }],
          },
        )

        expect { result }.not_to change { Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.size }
      end
    end

    context "with multiple rules" do
      it "fires when first rule matches" do
        freeze_time Time.utc(2026, 3, 18, 9, 0)
        create_schedule_workflow(
          configuration: {
            "rules" => [
              {
                "interval" => "days",
                "days_between_triggers" => 1,
                "trigger_at_hour" => 9,
                "trigger_at_minute" => 0,
              },
              { "interval" => "cron", "cron" => "0 12 * * *" },
            ],
          },
        )

        expect { result }.to change { Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.size }.by(1)
      end
    end

    context "when already triggered in the same minute" do
      it "does not fire twice" do
        freeze_time Time.utc(2026, 3, 18, 9, 0)
        create_schedule_workflow(
          configuration: {
            "rules" => [{ "interval" => "cron", "cron" => "0 9 * * *" }],
          },
        )

        described_class.call
        expect(Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.size).to eq(1)

        described_class.call
        expect(Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.size).to eq(1)
      end
    end

    context "when next matching minute arrives" do
      it "fires again" do
        freeze_time Time.utc(2026, 3, 18, 9, 0)
        create_schedule_workflow(
          configuration: {
            "rules" => [{ "interval" => "cron", "cron" => "0 * * * *" }],
          },
        )

        described_class.call
        expect(Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.size).to eq(1)

        freeze_time Time.utc(2026, 3, 18, 10, 0)
        described_class.call
        expect(Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.size).to eq(2)
      end
    end

    context "when workflow is disabled" do
      it "does not enqueue" do
        freeze_time Time.utc(2026, 3, 18, 9, 0)
        workflow =
          create_schedule_workflow(
            configuration: {
              "rules" => [{ "interval" => "cron", "cron" => "0 9 * * *" }],
            },
          )
        workflow.update!(enabled: false)

        expect { result }.not_to change { Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.size }
      end
    end

    context "with days recurrence (every 3 days)" do
      it "fires on first run" do
        freeze_time Time.utc(2026, 3, 18, 9, 0)
        create_schedule_workflow(
          configuration: {
            "rules" => [
              {
                "interval" => "days",
                "days_between_triggers" => 3,
                "trigger_at_hour" => 9,
                "trigger_at_minute" => 0,
              },
            ],
          },
        )

        expect { result }.to change { Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.size }.by(1)
      end

      it "skips when recurrence interval has not elapsed" do
        freeze_time Time.utc(2026, 3, 18, 9, 0)
        workflow =
          create_schedule_workflow(
            configuration: {
              "rules" => [
                {
                  "interval" => "days",
                  "days_between_triggers" => 3,
                  "trigger_at_hour" => 9,
                  "trigger_at_minute" => 0,
                },
              ],
            },
          )

        described_class.call
        expect(Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.size).to eq(1)

        freeze_time Time.utc(2026, 3, 19, 9, 0)
        described_class.call
        expect(Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.size).to eq(1)
      end

      it "fires when recurrence interval has elapsed" do
        freeze_time Time.utc(2026, 3, 18, 9, 0)
        workflow =
          create_schedule_workflow(
            configuration: {
              "rules" => [
                {
                  "interval" => "days",
                  "days_between_triggers" => 3,
                  "trigger_at_hour" => 9,
                  "trigger_at_minute" => 0,
                },
              ],
            },
          )

        described_class.call
        expect(Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.size).to eq(1)

        freeze_time Time.utc(2026, 3, 21, 9, 0)
        described_class.call
        expect(Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.size).to eq(2)
      end
    end

    context "with seconds interval watchdog" do
      it "starts a seconds chain when no recent trigger exists" do
        freeze_time Time.utc(2026, 3, 18, 9, 0)
        create_schedule_workflow(
          configuration: {
            "rules" => [{ "interval" => "seconds", "seconds_between_triggers" => 10 }],
          },
        )

        result
        expect(Jobs::DiscourseWorkflows::ExecuteSecondsSchedule.jobs.size).to eq(1)
      end

      it "does not start a chain when trigger fired recently" do
        freeze_time Time.utc(2026, 3, 18, 9, 0)
        workflow =
          create_schedule_workflow(
            configuration: {
              "rules" => [{ "interval" => "seconds", "seconds_between_triggers" => 10 }],
            },
          )

        DiscourseWorkflows::ScheduleRule.mark_seconds_triggered!(
          workflow,
          "trigger-1",
          0,
          Time.current.utc,
        )

        result
        expect(Jobs::DiscourseWorkflows::ExecuteSecondsSchedule.jobs.size).to eq(0)
      end

      it "skips seconds rules in cron matching" do
        freeze_time Time.utc(2026, 3, 18, 9, 0)
        create_schedule_workflow(
          configuration: {
            "rules" => [{ "interval" => "seconds", "seconds_between_triggers" => 10 }],
          },
        )

        result
        expect(Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.size).to eq(0)
      end
    end
  end
end
