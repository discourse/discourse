# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::ScheduleRule do
  fab!(:user)
  fab!(:workflow) { Fabricate(:discourse_workflows_workflow, created_by: user) }

  describe ".to_rrule" do
    it "returns nil for seconds (handled by self-rescheduling job)" do
      rule = { "interval" => "seconds", "seconds_between_triggers" => 30 }
      expect(described_class.to_rrule(rule)).to be_nil
    end

    it "converts minutes interval" do
      rule = { "interval" => "minutes", "minutes_between_triggers" => 5 }
      expect(described_class.to_rrule(rule)).to eq("FREQ=MINUTELY;INTERVAL=5")
    end

    it "converts hours interval with trigger_at_minute" do
      rule = { "interval" => "hours", "hours_between_triggers" => 2, "trigger_at_minute" => 15 }
      expect(described_class.to_rrule(rule)).to eq("FREQ=HOURLY;INTERVAL=2;BYMINUTE=15")
    end

    it "converts days interval" do
      rule = {
        "interval" => "days",
        "days_between_triggers" => 1,
        "trigger_at_hour" => 9,
        "trigger_at_minute" => 30,
      }
      expect(described_class.to_rrule(rule)).to eq("FREQ=DAILY;INTERVAL=1;BYHOUR=9;BYMINUTE=30")
    end

    it "converts weeks interval with weekdays" do
      rule = {
        "interval" => "weeks",
        "weeks_between_triggers" => 1,
        "trigger_on_weekdays" => [1, 5],
        "trigger_at_hour" => 8,
        "trigger_at_minute" => 0,
      }
      expect(described_class.to_rrule(rule)).to eq(
        "FREQ=WEEKLY;INTERVAL=1;BYDAY=MO,FR;BYHOUR=8;BYMINUTE=0",
      )
    end

    it "defaults to Sunday when weekdays empty" do
      rule = { "interval" => "weeks", "trigger_on_weekdays" => [] }
      expect(described_class.to_rrule(rule)).to include("BYDAY=SU")
    end

    it "converts months interval" do
      rule = {
        "interval" => "months",
        "months_between_triggers" => 3,
        "trigger_at_day_of_month" => 15,
        "trigger_at_hour" => 12,
        "trigger_at_minute" => 0,
      }
      expect(described_class.to_rrule(rule)).to eq(
        "FREQ=MONTHLY;INTERVAL=3;BYMONTHDAY=15;BYHOUR=12;BYMINUTE=0",
      )
    end

    it "clamps values to valid ranges" do
      rule = { "interval" => "minutes", "minutes_between_triggers" => 100 }
      expect(described_class.to_rrule(rule)).to eq("FREQ=MINUTELY;INTERVAL=59")
    end
  end

  describe ".matches_now?" do
    let(:dtstart) { Time.utc(2026, 1, 1, 0, 0) }

    it "returns false for seconds rules" do
      rule = { "interval" => "seconds" }
      expect(described_class.matches_now?(rule, dtstart, Time.current.utc)).to be(false)
    end

    it "matches cron rules via CronParser" do
      freeze_time Time.utc(2026, 3, 18, 9, 0)
      rule = { "interval" => "cron", "cron" => "0 9 * * *" }
      expect(described_class.matches_now?(rule, dtstart, Time.current.utc)).to be(true)
    end

    it "does not match cron at wrong time" do
      freeze_time Time.utc(2026, 3, 18, 10, 0)
      rule = { "interval" => "cron", "cron" => "0 9 * * *" }
      expect(described_class.matches_now?(rule, dtstart, Time.current.utc)).to be(false)
    end

    it "matches minutes interval" do
      freeze_time Time.utc(2026, 3, 18, 9, 10)
      rule = { "interval" => "minutes", "minutes_between_triggers" => 5 }
      expect(described_class.matches_now?(rule, dtstart, Time.current.utc)).to be(true)
    end

    it "does not match minutes at wrong time" do
      freeze_time Time.utc(2026, 3, 18, 9, 11)
      rule = { "interval" => "minutes", "minutes_between_triggers" => 5 }
      expect(described_class.matches_now?(rule, dtstart, Time.current.utc)).to be(false)
    end

    it "matches hours interval at correct minute" do
      freeze_time Time.utc(2026, 3, 18, 10, 30)
      rule = { "interval" => "hours", "hours_between_triggers" => 2, "trigger_at_minute" => 30 }
      expect(described_class.matches_now?(rule, dtstart, Time.current.utc)).to be(true)
    end

    it "matches daily interval" do
      freeze_time Time.utc(2026, 3, 18, 9, 0)
      rule = {
        "interval" => "days",
        "days_between_triggers" => 1,
        "trigger_at_hour" => 9,
        "trigger_at_minute" => 0,
      }
      expect(described_class.matches_now?(rule, dtstart, Time.current.utc)).to be(true)
    end

    it "matches weekly on correct weekday" do
      freeze_time Time.utc(2026, 3, 16, 8, 0) # Monday
      rule = {
        "interval" => "weeks",
        "weeks_between_triggers" => 1,
        "trigger_on_weekdays" => [1],
        "trigger_at_hour" => 8,
        "trigger_at_minute" => 0,
      }
      expect(described_class.matches_now?(rule, dtstart, Time.current.utc)).to be(true)
    end

    it "does not match weekly on wrong weekday" do
      freeze_time Time.utc(2026, 3, 17, 8, 0) # Tuesday
      rule = {
        "interval" => "weeks",
        "weeks_between_triggers" => 1,
        "trigger_on_weekdays" => [1],
        "trigger_at_hour" => 8,
        "trigger_at_minute" => 0,
      }
      expect(described_class.matches_now?(rule, dtstart, Time.current.utc)).to be(false)
    end

    it "matches monthly on correct day" do
      freeze_time Time.utc(2026, 3, 15, 12, 0)
      rule = {
        "interval" => "months",
        "months_between_triggers" => 1,
        "trigger_at_day_of_month" => 15,
        "trigger_at_hour" => 12,
        "trigger_at_minute" => 0,
      }
      expect(described_class.matches_now?(rule, dtstart, Time.current.utc)).to be(true)
    end

    it "handles every-3-days recurrence correctly" do
      dtstart = Time.utc(2026, 3, 15, 9, 0)
      rule = {
        "interval" => "days",
        "days_between_triggers" => 3,
        "trigger_at_hour" => 9,
        "trigger_at_minute" => 0,
      }

      freeze_time Time.utc(2026, 3, 18, 9, 0) # 3 days later
      expect(described_class.matches_now?(rule, dtstart, Time.current.utc)).to be(true)

      freeze_time Time.utc(2026, 3, 19, 9, 0) # 4 days later
      expect(described_class.matches_now?(rule, dtstart, Time.current.utc)).to be(false)

      freeze_time Time.utc(2026, 3, 21, 9, 0) # 6 days later
      expect(described_class.matches_now?(rule, dtstart, Time.current.utc)).to be(true)
    end
  end

  describe ".rules_from_configuration" do
    it "returns rules array" do
      config = { "rules" => [{ "interval" => "days" }] }
      expect(described_class.rules_from_configuration(config)).to eq([{ "interval" => "days" }])
    end

    it "returns empty array for empty config" do
      expect(described_class.rules_from_configuration({})).to eq([])
    end
  end

  describe ".valid_rule?" do
    it "validates cron rules" do
      expect(described_class.valid_rule?({ "interval" => "cron", "cron" => "0 9 * * *" })).to eq(
        true,
      )
    end

    it "rejects invalid cron" do
      expect(described_class.valid_rule?({ "interval" => "cron", "cron" => "invalid" })).to eq(
        false,
      )
    end

    it "validates interval rules" do
      expect(
        described_class.valid_rule?({ "interval" => "minutes", "minutes_between_triggers" => 5 }),
      ).to be(true)
    end

    it "validates seconds rules" do
      expect(
        described_class.valid_rule?({ "interval" => "seconds", "seconds_between_triggers" => 30 }),
      ).to be(true)
    end

    it "rejects seconds out of range" do
      expect(
        described_class.valid_rule?({ "interval" => "seconds", "seconds_between_triggers" => 0 }),
      ).to be(false)
    end

    it "rejects unknown intervals" do
      expect(described_class.valid_rule?({ "interval" => "unknown" })).to be(false)
    end
  end

  describe ".fire_matching_trigger!" do
    fab!(:schedule_workflow, :discourse_workflows_workflow) do
      graph =
        build_workflow_graph do |g|
          g.node "trigger-1",
                 "trigger:schedule",
                 configuration: {
                   "rules" => [{ "interval" => "cron", "cron" => "0 9 * * *" }],
                 }
        end
      Fabricate(:discourse_workflows_workflow, enabled: true, created_by: user, **graph)
    end

    let(:node) { schedule_workflow.nodes.first }

    it "enqueues a workflow execution job when a rule matches" do
      freeze_time Time.utc(2026, 3, 18, 9, 0)

      expect {
        described_class.fire_matching_trigger!(schedule_workflow, node, Time.current.utc)
      }.to change { Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.size }.by(1)

      job = Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.last
      expect(job["args"].first["workflow_id"]).to eq(schedule_workflow.id)
      expect(job["args"].first["trigger_node_id"]).to eq("trigger-1")
    end

    it "does not enqueue when no rule matches" do
      freeze_time Time.utc(2026, 3, 18, 10, 0)

      expect {
        described_class.fire_matching_trigger!(schedule_workflow, node, Time.current.utc)
      }.not_to change { Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.size }
    end

    it "does not fire twice in the same minute" do
      freeze_time Time.utc(2026, 3, 18, 9, 0)
      now = Time.current.utc

      described_class.fire_matching_trigger!(schedule_workflow, node, now)
      expect(Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.size).to eq(1)

      described_class.fire_matching_trigger!(schedule_workflow, node, now)
      expect(Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.size).to eq(1)
    end

    it "skips seconds rules" do
      freeze_time Time.utc(2026, 3, 18, 9, 0)
      seconds_node = {
        "id" => "trigger-2",
        "configuration" => {
          "rules" => [{ "interval" => "seconds", "seconds_between_triggers" => 10 }],
        },
      }

      expect {
        described_class.fire_matching_trigger!(schedule_workflow, seconds_node, Time.current.utc)
      }.not_to change { Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.size }
    end
  end

  describe ".restart_stalled_chains!" do
    fab!(:seconds_workflow, :discourse_workflows_workflow) do
      graph =
        build_workflow_graph do |g|
          g.node "trigger-1",
                 "trigger:schedule",
                 configuration: {
                   "rules" => [{ "interval" => "seconds", "seconds_between_triggers" => 10 }],
                 }
        end
      Fabricate(:discourse_workflows_workflow, enabled: true, created_by: user, **graph)
    end

    let(:node) { seconds_workflow.nodes.first }

    it "starts a seconds chain when no recent trigger exists" do
      freeze_time Time.utc(2026, 3, 18, 9, 0)

      described_class.restart_stalled_chains!(seconds_workflow, node, Time.current.utc)
      expect(Jobs::DiscourseWorkflows::ExecuteSecondsSchedule.jobs.size).to eq(1)
    end

    it "does not restart a chain when trigger fired recently" do
      freeze_time Time.utc(2026, 3, 18, 9, 0)

      described_class.mark_seconds_triggered!(seconds_workflow, "trigger-1", 0, Time.current.utc)
      described_class.restart_stalled_chains!(seconds_workflow, node, Time.current.utc)
      expect(Jobs::DiscourseWorkflows::ExecuteSecondsSchedule.jobs.size).to eq(0)
    end

    it "skips non-seconds rules" do
      freeze_time Time.utc(2026, 3, 18, 9, 0)
      cron_node = {
        "id" => "trigger-2",
        "configuration" => {
          "rules" => [{ "interval" => "cron", "cron" => "0 9 * * *" }],
        },
      }

      described_class.restart_stalled_chains!(seconds_workflow, cron_node, Time.current.utc)
      expect(Jobs::DiscourseWorkflows::ExecuteSecondsSchedule.jobs.size).to eq(0)
    end
  end

  describe ".start_seconds_chain!" do
    it "stores a token and enqueues a job" do
      rule = { "interval" => "seconds", "seconds_between_triggers" => 10 }
      described_class.start_seconds_chain!(workflow, "trigger-1", 0, rule)

      data = workflow.reload.node_static_data("trigger-1")
      expect(data.dig("seconds_tokens", "0")).to be_present
    end
  end

  describe ".seconds_token_valid?" do
    it "returns true for matching token" do
      rule = { "interval" => "seconds", "seconds_between_triggers" => 10 }
      described_class.start_seconds_chain!(workflow, "trigger-1", 0, rule)
      token = workflow.reload.node_static_data("trigger-1").dig("seconds_tokens", "0")

      expect(described_class.seconds_token_valid?(workflow, "trigger-1", 0, token)).to be(true)
    end

    it "returns false for stale token" do
      expect(described_class.seconds_token_valid?(workflow, "trigger-1", 0, "old-token")).to eq(
        false,
      )
    end
  end
end
