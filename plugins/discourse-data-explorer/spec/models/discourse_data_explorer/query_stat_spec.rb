# frozen_string_literal: true

RSpec.describe DiscourseDataExplorer::QueryStat do
  fab!(:query)

  describe ".log" do
    it "creates a row with a single run" do
      described_class.log(query.id)

      expect(described_class.find_by(query_id: query.id, date: Date.current).total_runs).to eq(1)
    end

    it "increments total_runs for the same query and day" do
      3.times { described_class.log(query.id) }

      expect(described_class.where(query_id: query.id).count).to eq(1)
      expect(described_class.find_by(query_id: query.id).total_runs).to eq(3)
    end
  end

  describe "DiscourseDataExplorer::Query#record_run!" do
    it "bumps last_run_at without touching updated_at and records a run" do
      query.update_columns(
        created_at: 10.days.ago,
        updated_at: 10.days.ago,
        last_run_at: 10.days.ago,
      )
      original_updated_at = query.reload.updated_at

      freeze_time

      expect { query.record_run! }.to change {
        described_class.where(query_id: query.id).sum(:total_runs)
      }.by(1)

      query.reload
      expect(query.last_run_at).to be_within(1.second).of(Time.current)
      expect(query.updated_at).to be_within(1.second).of(original_updated_at)
    end

    it "persists a default (unpersisted) query on run without recording a stat" do
      default_query = DiscourseDataExplorer::Query.new(id: -100, name: "Default", sql: "SELECT 1")

      expect { default_query.record_run! }.not_to change { described_class.count }
      expect(default_query.reload.last_run_at).to be_present
    end
  end
end
