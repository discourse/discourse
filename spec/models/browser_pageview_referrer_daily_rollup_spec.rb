# frozen_string_literal: true

RSpec.describe BrowserPageviewReferrerDailyRollup do
  describe ".aggregate" do
    let(:start_date) { 3.days.ago.to_date }
    let(:end_date) { Date.current }

    it "groups events by date and normalized_referrer into one row per combination" do
      Fabricate(:browser_pageview_event, normalized_referrer: "google.com")
      Fabricate(:browser_pageview_event, normalized_referrer: "google.com")
      Fabricate(:browser_pageview_event, normalized_referrer: "reddit.com")

      described_class.aggregate(start_date: start_date, end_date: end_date)

      rollups = described_class.order(:normalized_referrer).pluck(:normalized_referrer, :count)
      expect(rollups).to contain_exactly(["google.com", 2], ["reddit.com", 1])
    end

    it "splits total count from logged-in count" do
      user = Fabricate(:user)
      Fabricate(:browser_pageview_event, normalized_referrer: "google.com", user_id: user.id)
      Fabricate(:browser_pageview_event, normalized_referrer: "google.com")

      described_class.aggregate(start_date: start_date, end_date: end_date)

      row = described_class.find_by(normalized_referrer: "google.com")
      expect(row.count).to eq(2)
      expect(row.logged_in_count).to eq(1)
    end

    it "stores NULL-referrer rows (direct visits)" do
      Fabricate(:browser_pageview_event, normalized_referrer: nil)
      Fabricate(:browser_pageview_event, normalized_referrer: "google.com")

      described_class.aggregate(start_date: start_date, end_date: end_date)

      expect(described_class.where(normalized_referrer: nil).first.count).to eq(1)
    end

    it "stores internal-referrer rows so the data remains recoverable on hostname or rule changes" do
      Fabricate(:browser_pageview_event, normalized_referrer: "forum.example.com")
      Fabricate(:browser_pageview_event, normalized_referrer: "forum.example.com/t/topic/1")
      Fabricate(:browser_pageview_event, normalized_referrer: "google.com")

      described_class.aggregate(start_date: start_date, end_date: end_date)

      expect(described_class.pluck(:normalized_referrer)).to contain_exactly(
        "forum.example.com",
        "forum.example.com/t/topic/1",
        "google.com",
      )
    end

    it "is idempotent — running twice produces the same totals" do
      Fabricate(:browser_pageview_event, normalized_referrer: "google.com")
      Fabricate(:browser_pageview_event, normalized_referrer: "google.com")

      described_class.aggregate(start_date: start_date, end_date: end_date)
      described_class.aggregate(start_date: start_date, end_date: end_date)

      expect(described_class.where(normalized_referrer: "google.com").sum(:count)).to eq(2)
    end

    it "is idempotent for NULL referrer rows" do
      Fabricate(:browser_pageview_event, normalized_referrer: nil)
      Fabricate(:browser_pageview_event, normalized_referrer: nil)

      described_class.aggregate(start_date: start_date, end_date: end_date)
      described_class.aggregate(start_date: start_date, end_date: end_date)

      null_rows = described_class.where(normalized_referrer: nil)
      expect(null_rows.count).to eq(1)
      expect(null_rows.first.count).to eq(2)
    end

    it "only aggregates events within the requested date range" do
      Fabricate(:browser_pageview_event, normalized_referrer: "google.com", created_at: 10.days.ago)
      Fabricate(:browser_pageview_event, normalized_referrer: "google.com", created_at: 1.day.ago)

      described_class.aggregate(start_date: start_date, end_date: end_date)

      expect(described_class.sum(:count)).to eq(1)
    end
  end

  describe ".recompute" do
    it "produces a rollup row only for referrers that have events on the date" do
      date = 2.days.ago.to_date
      described_class.create!(date:, normalized_referrer: nil, count: 2, logged_in_count: 0)
      2.times do
        Fabricate(:browser_pageview_event, normalized_referrer: "google.com", created_at: date)
      end

      described_class.recompute([date])

      expect(described_class.where(date:).pluck(:normalized_referrer, :count)).to contain_exactly(
        ["google.com", 2],
      )
    end

    it "produces a NULL rollup row for pageviews with no referrer" do
      date = 2.days.ago.to_date
      Fabricate(:browser_pageview_event, normalized_referrer: nil, created_at: date)
      Fabricate(:browser_pageview_event, normalized_referrer: "reddit.com", created_at: date)

      described_class.recompute([date])

      expect(described_class.where(date:).pluck(:normalized_referrer, :count)).to contain_exactly(
        [nil, 1],
        ["reddit.com", 1],
      )
    end

    it "only recomputes the given dates" do
      requested_date = 2.days.ago.to_date
      untouched_date = 5.days.ago.to_date
      described_class.create!(
        date: untouched_date,
        normalized_referrer: "stale.example.com",
        count: 9,
        logged_in_count: 4,
      )
      Fabricate(
        :browser_pageview_event,
        normalized_referrer: "google.com",
        created_at: requested_date,
      )
      Fabricate(
        :browser_pageview_event,
        normalized_referrer: "bing.com",
        created_at: untouched_date,
      )

      described_class.recompute([requested_date])

      expect(described_class.where(date: requested_date).pluck(:normalized_referrer)).to eq(
        ["google.com"],
      )
      expect(
        described_class.where(date: untouched_date).pluck(
          :normalized_referrer,
          :count,
          :logged_in_count,
        ),
      ).to eq([["stale.example.com", 9, 4]])
    end

    it "leaves an existing rollup untouched for a date whose events are gone" do
      date = 2.days.ago.to_date
      described_class.create!(
        date:,
        normalized_referrer: "google.com",
        count: 5,
        logged_in_count: 2,
      )

      described_class.recompute([date])

      expect(
        described_class.where(date:).pluck(:normalized_referrer, :count, :logged_in_count),
      ).to eq([["google.com", 5, 2]])
    end

    it "rebuilds dates that have events while leaving dates without events untouched" do
      date_live = 2.days.ago.to_date
      date_gone = 5.days.ago.to_date
      described_class.create!(
        date: date_gone,
        normalized_referrer: "stale.example.com",
        count: 9,
        logged_in_count: 0,
      )
      Fabricate(:browser_pageview_event, normalized_referrer: "google.com", created_at: date_live)

      described_class.recompute([date_gone, date_live])

      expect(described_class.where(date: date_gone).pluck(:normalized_referrer, :count)).to eq(
        [["stale.example.com", 9]],
      )
      expect(described_class.where(date: date_live).pluck(:normalized_referrer, :count)).to eq(
        [["google.com", 1]],
      )
    end
  end
end
