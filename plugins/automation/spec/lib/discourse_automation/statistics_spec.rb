# frozen_string_literal: true

RSpec.describe DiscourseAutomation::Statistics do
  before { freeze_time(Time.utc(2026, 6, 15, 12, 0)) }

  def create_stat(automation_id, date:, runs: 1)
    DiscourseAutomation::Stat.create!(
      automation_id: automation_id,
      date: date,
      last_run_at: date.to_time + 10.hours,
      total_time: 1.0,
      average_run_time: 1.0,
      min_run_time: 1.0,
      max_run_time: 1.0,
      total_runs: runs,
      total_errors: 0,
    )
  end

  describe ".total" do
    it "counts every automation" do
      Fabricate(:automation)
      Fabricate(:automation)

      expect(described_class.total).to eq(count: 2)
    end
  end

  describe ".created" do
    it "counts automations created within each window" do
      Fabricate(:automation)
      Fabricate(:automation).update_columns(created_at: 10.days.ago)
      Fabricate(:automation).update_columns(created_at: 45.days.ago)

      expect(described_class.created).to eq(
        last_day: 1,
        "7_days": 1,
        "30_days": 2,
        previous_30_days: 1,
      )
    end
  end

  describe ".edited" do
    it "counts automations modified after creation, ignoring never-edited ones" do
      recently = Fabricate(:automation)
      recently.update_columns(created_at: 3.days.ago, updated_at: Time.current)

      previously = Fabricate(:automation)
      previously.update_columns(created_at: 50.days.ago, updated_at: 45.days.ago)

      never_edited = Fabricate(:automation)
      never_edited.update_columns(created_at: 5.days.ago, updated_at: 5.days.ago)

      expect(described_class.edited).to eq(
        last_day: 1,
        "7_days": 1,
        "30_days": 1,
        previous_30_days: 1,
      )
    end
  end

  describe ".executed" do
    it "counts distinct automations with runs in each window" do
      create_stat(1, date: Date.current, runs: 3)
      create_stat(1, date: 10.days.ago.to_date, runs: 2)
      create_stat(2, date: 45.days.ago.to_date, runs: 5)

      expect(described_class.executed).to eq(
        last_day: 1,
        "7_days": 1,
        "30_days": 1,
        previous_30_days: 1,
      )
    end
  end

  describe ".executions" do
    it "sums runs in each window plus a lifetime count" do
      create_stat(1, date: Date.current, runs: 3)
      create_stat(1, date: 10.days.ago.to_date, runs: 2)
      create_stat(1, date: 45.days.ago.to_date, runs: 5)

      expect(described_class.executions).to eq(
        last_day: 3,
        "7_days": 3,
        "30_days": 5,
        previous_30_days: 5,
        count: 10,
      )
    end
  end
end
