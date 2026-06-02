# frozen_string_literal: true

describe Reports::TopReferrersByBrowserPageviews do
  describe ".report_top_referrers_by_browser_pageviews" do
    let(:start_date) { 7.days.ago.to_date }
    let(:end_date) { Date.today }

    before { Discourse.stubs(:current_hostname).returns("forum.example.com") }

    let(:report) do
      BrowserPageviewReferrerDailyRollup.aggregate(start_date: start_date, end_date: end_date)
      BrowserPageviewEvent.delete_all
      Report.find("top_referrers_by_browser_pageviews", start_date: start_date, end_date: end_date)
    end

    it "ranks referrers by event count and computes each percent as a share of referred pageviews" do
      3.times do
        Fabricate(:browser_pageview_event, normalized_referrer: "news.ycombinator.com/item?id=1")
      end
      1.times { Fabricate(:browser_pageview_event, normalized_referrer: "reddit.com/r/discourse") }

      data = report.data
      expect(data.map { |row| row[:normalized_referrer] }).to eq(
        %w[news.ycombinator.com/item?id=1 reddit.com/r/discourse],
      )
      expect(data.map { |row| row[:percent] }).to eq([75, 25])
    end

    it "excludes direct (no-referrer) pageviews from both numerator and percent denominator" do
      2.times { Fabricate(:browser_pageview_event, normalized_referrer: "google.com") }
      2.times { Fabricate(:browser_pageview_event, normalized_referrer: nil) }

      data = report.data
      expect(data.map { |row| row[:normalized_referrer] }).to eq(["google.com"])
      expect(data.first[:percent]).to eq(100)
    end

    it "excludes same-host bare, path-prefixed, and query-prefixed referrers from numerator and denominator" do
      Fabricate(:browser_pageview_event, normalized_referrer: "forum.example.com")
      Fabricate(:browser_pageview_event, normalized_referrer: "forum.example.com/t/topic/1")
      Fabricate(:browser_pageview_event, normalized_referrer: "forum.example.com?ref=email")
      Fabricate(:browser_pageview_event, normalized_referrer: "google.com")

      data = report.data
      expect(data.map { |row| row[:normalized_referrer] }).to eq(["google.com"])
      expect(data.first[:percent]).to eq(100)
    end

    it "does not exclude hosts that merely share a prefix with current_hostname" do
      Fabricate(:browser_pageview_event, normalized_referrer: "evilforum.example.com/x")

      expect(report.data.map { |row| row[:normalized_referrer] }).to eq(["evilforum.example.com/x"])
    end

    it "handles current_hostname capitalization and www prefix consistently with the normalizer" do
      Discourse.stubs(:current_hostname).returns("Forum.Example.Com")
      Fabricate(:browser_pageview_event, normalized_referrer: "forum.example.com")
      Fabricate(:browser_pageview_event, normalized_referrer: "google.com")

      expect(report.data.map { |row| row[:normalized_referrer] }).to eq(["google.com"])
    end

    it "excludes same-host referrers when current_hostname is an IDN" do
      Discourse.stubs(:current_hostname).returns("münchen.de")
      Fabricate(:browser_pageview_event, normalized_referrer: "xn--mnchen-3ya.de/blog")
      Fabricate(:browser_pageview_event, normalized_referrer: "google.com")

      expect(report.data.map { |row| row[:normalized_referrer] }).to eq(["google.com"])
    end

    it "escapes LIKE wildcards in current_hostname so other hosts do not over-match" do
      Discourse.stubs(:current_hostname).returns("my_blog.example.com")
      # `_` is a single-char wildcard in LIKE; without escaping, the pattern
      # `my_blog.example.com/%` would match `my-blog.example.com/x` too.
      Fabricate(:browser_pageview_event, normalized_referrer: "my-blog.example.com/x")
      Fabricate(:browser_pageview_event, normalized_referrer: "google.com")

      expect(report.data.map { |row| row[:normalized_referrer] }).to contain_exactly(
        "my-blog.example.com/x",
        "google.com",
      )
    end

    it "counts only logged-in events in both numerator and denominator when login_required is true" do
      SiteSetting.login_required = true
      user = Fabricate(:user)
      Fabricate(:browser_pageview_event, normalized_referrer: "google.com", user_id: user.id)
      Fabricate(:browser_pageview_event, normalized_referrer: "google.com") # anonymous, ignored
      Fabricate(:browser_pageview_event, normalized_referrer: "reddit.com", user_id: user.id)

      expect(report.data.first[:count]).to eq(1)
    end

    it "returns empty data when no qualifying events exist" do
      Fabricate(:browser_pageview_event, normalized_referrer: nil)
      expect(report.data).to eq([])
    end

    it "caps displayed rows at MAX_ROWS but keeps every external referrer in the percent denominator" do
      stub_const(Reports::TopReferrersByBrowserPageviews, "MAX_ROWS", 2) do
        5.times { Fabricate(:browser_pageview_event, normalized_referrer: "a.example.com") }
        3.times { Fabricate(:browser_pageview_event, normalized_referrer: "b.example.com") }
        2.times { Fabricate(:browser_pageview_event, normalized_referrer: "c.example.com") }

        expect(report.data.map { |row| row[:normalized_referrer] }).to eq(
          %w[a.example.com b.example.com],
        )
        expect(report.data.map { |row| row[:percent] }).to eq([50, 30])
      end
    end
  end
end
