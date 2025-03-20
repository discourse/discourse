# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscourseAutomation::Stat do
  let(:automation_id) { 42 }
  let(:another_automation_id) { 43 }
  let(:run_time) { 0.5 }

  describe ".log" do
    context "with block form" do
      it "measures the execution time and records it" do
        # Mock Process.clock_gettime to return controlled values
        allow(Process).to receive(:clock_gettime).and_return(10, 10.75)

        result = DiscourseAutomation::Stat.log(automation_id) { "test result" }

        expect(result).to eq("test result")

        stat = DiscourseAutomation::Stat.find_by(automation_id: automation_id)
        expect(stat.total_time).to eq(0.75)
        expect(stat.average_run_time).to eq(0.75)
        expect(stat.min_run_time).to eq(0.75)
        expect(stat.max_run_time).to eq(0.75)
        expect(stat.total_runs).to eq(1)
      end
    end

    context "with direct call form" do
      it "logs the provided run time" do
        DiscourseAutomation::Stat.log(automation_id, run_time)

        stat = DiscourseAutomation::Stat.find_by(automation_id: automation_id)
        expect(stat.total_time).to eq(run_time)
        expect(stat.average_run_time).to eq(run_time)
        expect(stat.min_run_time).to eq(run_time)
        expect(stat.max_run_time).to eq(run_time)
        expect(stat.total_runs).to eq(1)
      end
    end

    context "when updating existing stats" do
      before do
        freeze_time DateTime.parse("2023-01-01 12:00:00")
        DiscourseAutomation::Stat.log(automation_id, 0.5)
      end

      it "updates stats correctly for the same automation on the same day" do
        freeze_time DateTime.parse("2023-01-01 14:00:00")
        DiscourseAutomation::Stat.log(automation_id, 1.5)

        stat = DiscourseAutomation::Stat.find_by(automation_id: automation_id)
        expect(stat.total_time).to eq(2.0) # 0.5 + 1.5
        expect(stat.average_run_time).to eq(1.0) # (0.5 + 1.5) / 2
        expect(stat.min_run_time).to eq(0.5)
        expect(stat.max_run_time).to eq(1.5)
        expect(stat.total_runs).to eq(2)
        expect(stat.last_run_at.to_s).to include("2023-01-01 14:00:00")
      end

      it "creates a new record for the same automation on a different day" do
        freeze_time DateTime.parse("2023-01-02 12:00:00")
        DiscourseAutomation::Stat.log(automation_id, 2.0)

        # There should be two records now
        expect(DiscourseAutomation::Stat.where(automation_id: automation_id).count).to eq(2)

        # Check first day's stats
        day1_stat =
          DiscourseAutomation::Stat.find_by(automation_id: automation_id, date: "2023-01-01")
        expect(day1_stat.total_time).to eq(0.5)
        expect(day1_stat.total_runs).to eq(1)

        # Check second day's stats
        day2_stat =
          DiscourseAutomation::Stat.find_by(automation_id: automation_id, date: "2023-01-02")
        expect(day2_stat.total_time).to eq(2.0)
        expect(day2_stat.total_runs).to eq(1)
      end

      it "handles multiple automations on the same day" do
        freeze_time DateTime.parse("2023-01-01 13:00:00")
        DiscourseAutomation::Stat.log(another_automation_id, 0.7)

        # Original automation should be unchanged
        first_stat = DiscourseAutomation::Stat.find_by(automation_id: automation_id)
        expect(first_stat.total_runs).to eq(1)
        expect(first_stat.total_time).to eq(0.5)

        # New automation should have its own stats
        second_stat = DiscourseAutomation::Stat.find_by(automation_id: another_automation_id)
        expect(second_stat.total_runs).to eq(1)
        expect(second_stat.total_time).to eq(0.7)
      end
    end

    context "with extreme values" do
      it "correctly tracks min/max values" do
        freeze_time DateTime.parse("2023-01-01 12:00:00")

        # First run
        DiscourseAutomation::Stat.log(automation_id, 5.0)

        # Second run with lower time
        DiscourseAutomation::Stat.log(automation_id, 2.0)

        # Third run with higher time
        DiscourseAutomation::Stat.log(automation_id, 10.0)

        stat = DiscourseAutomation::Stat.find_by(automation_id: automation_id)
        expect(stat.min_run_time).to eq(2.0)
        expect(stat.max_run_time).to eq(10.0)
        expect(stat.total_time).to eq(17.0)
        expect(stat.average_run_time).to eq(17.0 / 3)
        expect(stat.total_runs).to eq(3)
      end
    end
  end
end
