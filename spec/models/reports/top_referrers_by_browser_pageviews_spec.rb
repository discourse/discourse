# frozen_string_literal: true

describe Reports::TopReferrersByBrowserPageviews do
  describe ".report_top_referrers_by_browser_pageviews" do
    let(:start_date) { 7.days.ago.to_date }
    let(:end_date) { Date.today }

    before { Discourse.stubs(:current_hostname).returns("forum.example.com") }

    it "ranks referrers by event count and computes percent of total browser pageviews" do
      3.times do
        Fabricate(:browser_pageview_event, normalized_referrer: "news.ycombinator.com/item?id=1")
      end
      1.times { Fabricate(:browser_pageview_event, normalized_referrer: "reddit.com/r/discourse") }

      report =
        Report.find(
          "top_referrers_by_browser_pageviews",
          start_date: start_date,
          end_date: end_date,
        )
      expect(report.data.map { |row| row[:normalized_referrer] }).to eq(
        %w[news.ycombinator.com/item?id=1 reddit.com/r/discourse],
      )
      expect(report.data.first[:percent]).to eq(75)
    end

    it "excludes NULL normalized_referrer from numerator but includes in denominator" do
      2.times { Fabricate(:browser_pageview_event, normalized_referrer: "google.com") }
      2.times { Fabricate(:browser_pageview_event, normalized_referrer: nil) }

      report =
        Report.find(
          "top_referrers_by_browser_pageviews",
          start_date: start_date,
          end_date: end_date,
        )
      expect(report.data.map { |row| row[:normalized_referrer] }).to eq(["google.com"])
      expect(report.data.first[:percent]).to eq(50)
    end

    it "excludes same-host bare, path-prefixed, and query-prefixed referrers from numerator and denominator" do
      Fabricate(:browser_pageview_event, normalized_referrer: "forum.example.com")
      Fabricate(:browser_pageview_event, normalized_referrer: "forum.example.com/t/topic/1")
      Fabricate(:browser_pageview_event, normalized_referrer: "forum.example.com?ref=email")
      Fabricate(:browser_pageview_event, normalized_referrer: "google.com")

      report =
        Report.find(
          "top_referrers_by_browser_pageviews",
          start_date: start_date,
          end_date: end_date,
        )
      expect(report.data.map { |row| row[:normalized_referrer] }).to eq(["google.com"])
      expect(report.data.first[:percent]).to eq(100)
    end

    it "includes direct (no-referrer) pageviews in the denominator alongside external referrers" do
      2.times { Fabricate(:browser_pageview_event, normalized_referrer: "google.com") }
      2.times { Fabricate(:browser_pageview_event, normalized_referrer: nil) }
      Fabricate(:browser_pageview_event, normalized_referrer: "forum.example.com/t/topic/1")

      report =
        Report.find(
          "top_referrers_by_browser_pageviews",
          start_date: start_date,
          end_date: end_date,
        )
      expect(report.data.map { |row| row[:normalized_referrer] }).to eq(["google.com"])
      expect(report.data.first[:percent]).to eq(50)
    end

    it "does not exclude hosts that merely share a prefix with current_hostname" do
      Fabricate(:browser_pageview_event, normalized_referrer: "evilforum.example.com/x")
      report =
        Report.find(
          "top_referrers_by_browser_pageviews",
          start_date: start_date,
          end_date: end_date,
        )
      expect(report.data.map { |row| row[:normalized_referrer] }).to eq(["evilforum.example.com/x"])
    end

    it "handles current_hostname capitalization and www prefix consistently with the normalizer" do
      Discourse.stubs(:current_hostname).returns("Forum.Example.Com")
      Fabricate(:browser_pageview_event, normalized_referrer: "forum.example.com")
      Fabricate(:browser_pageview_event, normalized_referrer: "google.com")

      report =
        Report.find(
          "top_referrers_by_browser_pageviews",
          start_date: start_date,
          end_date: end_date,
        )
      expect(report.data.map { |row| row[:normalized_referrer] }).to eq(["google.com"])
    end

    it "excludes same-host referrers when current_hostname is an IDN" do
      Discourse.stubs(:current_hostname).returns("münchen.de")
      Fabricate(:browser_pageview_event, normalized_referrer: "xn--mnchen-3ya.de/blog")
      Fabricate(:browser_pageview_event, normalized_referrer: "google.com")

      report =
        Report.find(
          "top_referrers_by_browser_pageviews",
          start_date: start_date,
          end_date: end_date,
        )
      expect(report.data.map { |row| row[:normalized_referrer] }).to eq(["google.com"])
    end

    it "escapes LIKE wildcards in current_hostname so other hosts do not over-match" do
      Discourse.stubs(:current_hostname).returns("my_blog.example.com")
      # `_` is a single-char wildcard in LIKE; without escaping, the pattern
      # `my_blog.example.com/%` would match `my-blog.example.com/x` too.
      Fabricate(:browser_pageview_event, normalized_referrer: "my-blog.example.com/x")
      Fabricate(:browser_pageview_event, normalized_referrer: "google.com")

      report =
        Report.find(
          "top_referrers_by_browser_pageviews",
          start_date: start_date,
          end_date: end_date,
        )
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

      report =
        Report.find(
          "top_referrers_by_browser_pageviews",
          start_date: start_date,
          end_date: end_date,
        )
      expect(report.data.first[:count]).to eq(1)
    end

    it "returns empty data when no qualifying events exist" do
      Fabricate(:browser_pageview_event, normalized_referrer: nil)
      report =
        Report.find(
          "top_referrers_by_browser_pageviews",
          start_date: start_date,
          end_date: end_date,
        )
      expect(report.data).to eq([])
    end

    it "respects the limit opt" do
      6.times do |i|
        (i + 1).times do
          Fabricate(:browser_pageview_event, normalized_referrer: "site-#{i}.example.com")
        end
      end

      report =
        Report.find(
          "top_referrers_by_browser_pageviews",
          start_date: start_date,
          end_date: end_date,
          limit: 3,
        )
      expect(report.data.size).to eq(3)
    end
  end
end
