# frozen_string_literal: true

RSpec.describe BrowserPageviewReferrerDailyRollup do
  describe ".aggregate" do
    let(:start_date) { 3.days.ago.to_date }
    let(:end_date) { Date.current }

    before { Discourse.stubs(:current_hostname).returns("forum.example.com") }

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

    it "stores NULL-referrer rows (direct visits) for use in the denominator" do
      Fabricate(:browser_pageview_event, normalized_referrer: nil)
      Fabricate(:browser_pageview_event, normalized_referrer: "google.com")

      described_class.aggregate(start_date: start_date, end_date: end_date)

      expect(described_class.where(normalized_referrer: nil).first.count).to eq(1)
    end

    it "excludes same-host bare, path-prefixed, and query-prefixed referrers" do
      Fabricate(:browser_pageview_event, normalized_referrer: "forum.example.com")
      Fabricate(:browser_pageview_event, normalized_referrer: "forum.example.com/t/topic/1")
      Fabricate(:browser_pageview_event, normalized_referrer: "forum.example.com?ref=email")
      Fabricate(:browser_pageview_event, normalized_referrer: "google.com")

      described_class.aggregate(start_date: start_date, end_date: end_date)

      expect(described_class.pluck(:normalized_referrer)).to contain_exactly("google.com")
    end

    it "does not exclude hosts that merely share a prefix with current_hostname" do
      Fabricate(:browser_pageview_event, normalized_referrer: "evilforum.example.com/x")

      described_class.aggregate(start_date: start_date, end_date: end_date)

      expect(described_class.pluck(:normalized_referrer)).to eq(["evilforum.example.com/x"])
    end

    it "escapes LIKE wildcards in current_hostname so other hosts do not over-match" do
      Discourse.stubs(:current_hostname).returns("my_blog.example.com")
      Fabricate(:browser_pageview_event, normalized_referrer: "my-blog.example.com/x")
      Fabricate(:browser_pageview_event, normalized_referrer: "google.com")

      described_class.aggregate(start_date: start_date, end_date: end_date)

      expect(described_class.pluck(:normalized_referrer)).to contain_exactly(
        "my-blog.example.com/x",
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
end
