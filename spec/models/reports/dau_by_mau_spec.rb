# frozen_string_literal: true

describe Reports::DauByMau do
  describe ".report_dau_by_mau" do
    let(:report) { Report.find("dau_by_mau") }

    it "returns an empty report with no data" do
      expect(report.data).to be_blank
    end

    it "returns a report with data" do
      freeze_time_safe
      Fabricate(:user_visit_daily_rollup, date: 45.days.ago, dau: 1, mau: 1)
      Fabricate(:user_visit_daily_rollup, date: 35.days.ago, dau: 1, mau: 2)
      Fabricate(:user_visit_daily_rollup, date: 2.days.ago, dau: 2, mau: 2)
      Fabricate(:user_visit_daily_rollup, date: 1.day.ago, dau: 1, mau: 3)

      expect(report.data.first[:y]).to eq(100)
      expect(report.data.last[:y]).to eq(33.34)
      expect(report.prev30Days).to eq(75)
    end

    it "returns the current data and previous period average" do
      Fabricate(:user_visit_daily_rollup, date: Date.new(2026, 4, 9), dau: 1, mau: 1)
      Fabricate(:user_visit_daily_rollup, date: Date.new(2026, 4, 11), dau: 1, mau: 2)

      report =
        Report.find(
          "dau_by_mau",
          start_date: Time.zone.local(2026, 4, 10).beginning_of_day,
          end_date: Time.zone.local(2026, 4, 11).end_of_day,
          facets: [:prev_period],
        )

      expect(report.data).to eq([{ x: Date.new(2026, 4, 11), y: 50.0 }])
      expect(report.prev_period).to eq(100)
    end
  end
end
