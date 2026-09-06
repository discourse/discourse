# frozen_string_literal: true

RSpec.describe DiscourseDataExplorer::Statistics do
  before { freeze_time(Time.utc(2026, 6, 15, 12, 0)) }

  fab!(:user)

  def log_runs(query_id, date:, runs: 1)
    DiscourseDataExplorer::QueryStat.create!(query_id: query_id, date: date, total_runs: runs)
  end

  describe ".queries_total" do
    it "counts non-hidden user queries" do
      Fabricate(:query)
      Fabricate(:query)
      Fabricate(:query, hidden: true)

      expect(described_class.queries_total).to eq(count: 2)
    end
  end

  describe ".queries_created" do
    it "counts queries created within each window" do
      Fabricate(:query)
      Fabricate(:query).update_columns(created_at: 10.days.ago)
      Fabricate(:query).update_columns(created_at: 45.days.ago)

      expect(described_class.queries_created).to eq(
        last_day: 1,
        "7_days": 1,
        "30_days": 2,
        previous_30_days: 1,
      )
    end
  end

  describe ".queries_edited" do
    it "counts queries modified after creation, ignoring never-edited ones" do
      recently = Fabricate(:query)
      recently.update_columns(created_at: 3.days.ago, updated_at: Time.current)

      previously = Fabricate(:query)
      previously.update_columns(created_at: 50.days.ago, updated_at: 45.days.ago)

      never_edited = Fabricate(:query)
      never_edited.update_columns(created_at: 5.days.ago, updated_at: 5.days.ago)

      expect(described_class.queries_edited).to eq(
        last_day: 1,
        "7_days": 1,
        "30_days": 1,
        previous_30_days: 1,
      )
    end
  end

  describe ".queries_executed" do
    it "counts distinct queries with runs in each window" do
      log_runs(1, date: Date.current, runs: 3)
      log_runs(1, date: 10.days.ago.to_date, runs: 2)
      log_runs(2, date: 45.days.ago.to_date, runs: 5)

      expect(described_class.queries_executed).to eq(
        last_day: 1,
        "7_days": 1,
        "30_days": 1,
        previous_30_days: 1,
      )
    end
  end

  describe ".executions" do
    it "sums runs in each window plus a lifetime count" do
      log_runs(1, date: Date.current, runs: 3)
      log_runs(1, date: 10.days.ago.to_date, runs: 2)
      log_runs(1, date: 45.days.ago.to_date, runs: 5)

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
