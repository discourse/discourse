# frozen_string_literal: true

RSpec.describe BrowserPageviewCrawlerDailyRollup do
  describe ".aggregate" do
    let(:start_date) { 3.days.ago.to_date }
    let(:end_date) { Date.current }
    let(:above_threshold) { CrawlerScorer::BOT_SCORE_THRESHOLD + 1 }

    it "groups likely crawler events by date and logged in state" do
      user = Fabricate(:user)
      yesterday = 1.day.ago
      today = Time.current

      Fabricate(:browser_pageview_event, score: above_threshold, created_at: yesterday)
      Fabricate(:browser_pageview_event, score: above_threshold, created_at: today)
      Fabricate(
        :browser_pageview_event,
        score: above_threshold,
        user_id: user.id,
        created_at: today,
      )

      described_class.aggregate(start_date: start_date, end_date: end_date)

      expect(described_class.order(:date, :logged_in).pluck(:date, :logged_in, :count)).to eq(
        [[yesterday.to_date, false, 1], [today.to_date, false, 1], [today.to_date, true, 1]],
      )
    end

    it "ignores events at or below the threshold, and unscored events" do
      Fabricate(:browser_pageview_event, score: CrawlerScorer::BOT_SCORE_THRESHOLD)
      Fabricate(:browser_pageview_event, score: 0)
      Fabricate(:browser_pageview_event, score: nil)
      Fabricate(:browser_pageview_event, score: above_threshold)

      described_class.aggregate(start_date: start_date, end_date: end_date)

      expect(described_class.sum(:count)).to eq(1)
    end

    it "only aggregates events within the requested date range" do
      Fabricate(:browser_pageview_event, score: above_threshold, created_at: 10.days.ago)
      Fabricate(:browser_pageview_event, score: above_threshold, created_at: 1.day.ago)

      described_class.aggregate(start_date: start_date, end_date: end_date)

      expect(described_class.sum(:count)).to eq(1)
    end

    it "is idempotent and refreshes counts when re-aggregating" do
      Fabricate(:browser_pageview_event, score: above_threshold)
      described_class.aggregate(start_date: start_date, end_date: end_date)

      Fabricate(:browser_pageview_event, score: above_threshold)
      described_class.aggregate(start_date: start_date, end_date: end_date)

      expect(described_class.count).to eq(1)
      expect(described_class.sum(:count)).to eq(2)
    end

    it "is a no-op when no likely crawler events exist in the range" do
      Fabricate(:browser_pageview_event, score: nil)

      expect {
        described_class.aggregate(start_date: start_date, end_date: end_date)
      }.not_to change { described_class.count }
    end
  end
end
