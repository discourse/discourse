# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscourseAutomation::Stat do
  let(:automation_id) { 42 }
  let(:another_automation_id) { 43 }
  let(:run_time) { 0.5 }

  describe ".fetch_period_summaries" do
    let(:today) { Date.new(2023, 1, 10) }

    before do
      freeze_time today

      # Last day: 2 runs
      DiscourseAutomation::Stat.create!(
        automation_id: automation_id,
        date: today - 1.day,
        last_run_at: today - 1.day + 10.hours,
        total_time: 3.0,
        average_run_time: 1.5,
        min_run_time: 1.0,
        max_run_time: 2.0,
        total_runs: 2,
      )

      # Same day, different automation
      DiscourseAutomation::Stat.create!(
        automation_id: another_automation_id,
        date: today - 1.day,
        last_run_at: today - 1.day + 12.hours,
        total_time: 1.0,
        average_run_time: 1.0,
        min_run_time: 1.0,
        max_run_time: 1.0,
        total_runs: 1,
      )

      # Last week: 3 runs (including the day above)
      DiscourseAutomation::Stat.create!(
        automation_id: automation_id,
        date: today - 5.days,
        last_run_at: today - 5.days + 14.hours,
        total_time: 2.5,
        average_run_time: 1.25,
        min_run_time: 0.5,
        max_run_time: 2.0,
        total_runs: 2,
      )

      # Last month: 5 runs (including the week above)
      DiscourseAutomation::Stat.create!(
        automation_id: automation_id,
        date: today - 20.days,
        last_run_at: today - 20.days + 8.hours,
        total_time: 4.0,
        average_run_time: 2.0,
        min_run_time: 1.5,
        max_run_time: 2.5,
        total_runs: 2,
      )
    end

    it "returns correctly structured data for multiple periods" do
      summaries = DiscourseAutomation::Stat.fetch_period_summaries
      expect(summaries.keys).to contain_exactly(automation_id, another_automation_id)

      auto_summary = summaries[automation_id]
      expect(auto_summary.keys).to contain_exactly(:last_run_at, :last_day, :last_week, :last_month)
      expect(auto_summary[:last_run_at].to_date).to eq((today - 1.day).to_date)

      %i[last_day last_week last_month].each do |period|
        expect(auto_summary[period].keys).to contain_exactly(
          :total_runs,
          :total_time,
          :average_run_time,
          :min_run_time,
          :max_run_time,
        )
      end
    end

    it "correctly aggregates stats for different time periods" do
      auto_summary = DiscourseAutomation::Stat.fetch_period_summaries[automation_id]

      expect(auto_summary[:last_day]).to include(
        total_runs: 2,
        total_time: 3.0,
        min_run_time: 1.0,
        max_run_time: 2.0,
        average_run_time: 1.5,
      )

      expect(auto_summary[:last_week]).to include(
        total_runs: 4,
        total_time: 5.5,
        min_run_time: 0.5,
        max_run_time: 2.0,
      )

      expect(auto_summary[:last_month]).to include(
        total_runs: 6,
        total_time: 9.5,
        min_run_time: 0.5,
        max_run_time: 2.5,
      )
    end

    it "handles multiple automations correctly" do
      summaries = DiscourseAutomation::Stat.fetch_period_summaries

      # Check another_automation_id data
      other_summary = summaries[another_automation_id]
      expect(other_summary[:last_day][:total_runs]).to eq(1)
      expect(other_summary[:last_day][:total_time]).to eq(1.0)
      expect(other_summary[:last_run_at].to_date).to eq((today - 1.day).to_date)
    end

    it "returns empty hash when no stats exist" do
      DiscourseAutomation::Stat.delete_all
      expect(DiscourseAutomation::Stat.fetch_period_summaries).to eq({})
    end

    it "correctly handles automations with no stats in specific periods" do
      new_automation_id = 44

      DiscourseAutomation::Stat.create!(
        automation_id: new_automation_id,
        date: 2.days.from_now,
        last_run_at: 2.days.from_now,
        total_time: 1.0,
        average_run_time: 1.0,
        min_run_time: 1.0,
        max_run_time: 1.0,
        total_runs: 1,
      )

      summaries = DiscourseAutomation::Stat.fetch_period_summaries

      expect(summaries.keys).not_to include(new_automation_id)
    end
  end

  describe ".log" do
    context "with block form" do
      it "measures the execution time and records it" do
        # Mock Process.clock_gettime to return controlled values
        allow(Process).to receive(:clock_gettime).and_return(10.0, 10.75)

        result = DiscourseAutomation::Stat.log(automation_id) { "test result" }

        expect(result).to eq("test result")

        stat = DiscourseAutomation::Stat.find_by(automation_id: automation_id)
        expect(stat.total_time).to eq(0.75)
        expect(stat.average_run_time).to eq(0.75)
        expect(stat.min_run_time).to eq(0.75)
        expect(stat.max_run_time).to eq(0.75)
        expect(stat.total_runs).to eq(1)
      end

      context "when an error occurs" do
        it "yields the correct error and records it" do
          allow(Process).to receive(:clock_gettime).and_return(10.0, 10.75)

          expect { DiscourseAutomation::Stat.log(automation_id) { raise } }.to raise_error(
            RuntimeError,
          )

          stat = DiscourseAutomation::Stat.find_by(automation_id: automation_id)
          expect(stat.total_time).to eq(0.75)
          expect(stat.average_run_time).to eq(0.75)
          expect(stat.min_run_time).to eq(0.75)
          expect(stat.max_run_time).to eq(0.75)
          expect(stat.total_runs).to eq(1)
        end
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
