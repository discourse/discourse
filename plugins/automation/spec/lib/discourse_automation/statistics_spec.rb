# frozen_string_literal: true

RSpec.describe DiscourseAutomation::Statistics do
  before { freeze_time(Time.utc(2026, 6, 15, 12, 0)) }

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
    fab!(:current_automation_stat) do
      Fabricate(:automation_stat, automation_id: 1, date: Date.new(2026, 6, 15), total_runs: 3)
    end
    fab!(:recent_automation_stat) do
      Fabricate(:automation_stat, automation_id: 1, date: Date.new(2026, 6, 5), total_runs: 2)
    end
    fab!(:previous_automation_stat) do
      Fabricate(:automation_stat, automation_id: 2, date: Date.new(2026, 5, 1), total_runs: 5)
    end

    it "counts distinct automations with runs in each window" do
      expect(described_class.executed).to eq(
        last_day: 1,
        "7_days": 1,
        "30_days": 1,
        previous_30_days: 1,
      )
    end
  end

  describe ".executions" do
    fab!(:current_automation_stat) do
      Fabricate(:automation_stat, automation_id: 1, date: Date.new(2026, 6, 15), total_runs: 3)
    end
    fab!(:recent_automation_stat) do
      Fabricate(:automation_stat, automation_id: 1, date: Date.new(2026, 6, 5), total_runs: 2)
    end
    fab!(:previous_automation_stat) do
      Fabricate(:automation_stat, automation_id: 1, date: Date.new(2026, 5, 1), total_runs: 5)
    end

    it "sums runs in each window plus a lifetime count" do
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
