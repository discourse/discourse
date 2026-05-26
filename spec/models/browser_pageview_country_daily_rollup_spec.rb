# frozen_string_literal: true

RSpec.describe BrowserPageviewCountryDailyRollup do
  describe ".aggregate" do
    let(:start_date) { 3.days.ago.to_date }
    let(:end_date) { Date.current }

    it "groups events by date and country_code into one row per combination" do
      yesterday = 1.day.ago
      today = Time.current
      Fabricate(:browser_pageview_event, country_code: "US", created_at: yesterday)
      Fabricate(:browser_pageview_event, country_code: "US", created_at: today)
      Fabricate(:browser_pageview_event, country_code: "GB", created_at: today)

      described_class.aggregate(start_date: start_date, end_date: end_date)

      rollups = described_class.order(:date, :country_code).pluck(:date, :country_code, :count)
      expect(rollups).to contain_exactly(
        [yesterday.to_date, "US", 1],
        [today.to_date, "US", 1],
        [today.to_date, "GB", 1],
      )
    end

    it "splits total count from logged-in count" do
      user = Fabricate(:user)
      Fabricate(:browser_pageview_event, country_code: "US", user_id: user.id)
      Fabricate(:browser_pageview_event, country_code: "US")
      Fabricate(:browser_pageview_event, country_code: "US")

      described_class.aggregate(start_date: start_date, end_date: end_date)

      row = described_class.first
      expect(row.count).to eq(3)
      expect(row.logged_in_count).to eq(1)
    end

    it "stores rows for NULL country_code (no GeoIP match) without duplication on re-run" do
      Fabricate(:browser_pageview_event, country_code: nil)
      Fabricate(:browser_pageview_event, country_code: nil)

      described_class.aggregate(start_date: start_date, end_date: end_date)
      described_class.aggregate(start_date: start_date, end_date: end_date)

      null_rows = described_class.where(country_code: nil)
      expect(null_rows.count).to eq(1)
      expect(null_rows.first.count).to eq(2)
    end

    it "is idempotent — running twice produces the same totals" do
      Fabricate(:browser_pageview_event, country_code: "US")
      Fabricate(:browser_pageview_event, country_code: "US")

      described_class.aggregate(start_date: start_date, end_date: end_date)
      described_class.aggregate(start_date: start_date, end_date: end_date)

      expect(described_class.where(country_code: "US").sum(:count)).to eq(2)
    end

    it "updates existing rollup rows when re-aggregating with new events" do
      Fabricate(:browser_pageview_event, country_code: "US")
      described_class.aggregate(start_date: start_date, end_date: end_date)

      Fabricate(:browser_pageview_event, country_code: "US")
      described_class.aggregate(start_date: start_date, end_date: end_date)

      expect(described_class.where(country_code: "US").sum(:count)).to eq(2)
    end

    it "only aggregates events within the requested date range" do
      Fabricate(:browser_pageview_event, country_code: "US", created_at: 10.days.ago)
      Fabricate(:browser_pageview_event, country_code: "US", created_at: 1.day.ago)

      described_class.aggregate(start_date: start_date, end_date: end_date)

      expect(described_class.sum(:count)).to eq(1)
    end

    it "is a no-op when no events exist in the range" do
      expect {
        described_class.aggregate(start_date: start_date, end_date: end_date)
      }.not_to change { described_class.count }
    end
  end
end
