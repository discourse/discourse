# frozen_string_literal: true

RSpec.describe BrowserPageviewEntryUrlDailyRollup do
  before do
    freeze_time(Time.zone.local(2026, 5, 14, 12, 0, 0))
    RailsMultisite::ConnectionManagement.stubs(:current_db_hostnames).returns(
      %w[test.localhost alias.test.localhost],
    )
    Discourse.stubs(:current_hostname).returns("test.localhost")
  end

  describe ".aggregate" do
    it "counts direct and external-referrer pageviews but excludes configured site hosts" do
      topic = Fabricate(:topic)
      Fabricate(
        :browser_pageview_event,
        topic_id: topic.id,
        url: "https://test.localhost/t/topic/#{topic.id}?utm_source=email#post_1",
        referrer: "https://www.google.com/search?q=discourse",
        normalized_referrer: "google.com/search?q=discourse",
        normalized_referrer_version: BrowserPageviewEventUrlNormalizer::REFERRER_VERSION,
        created_at: "2026-05-12 10:00:00",
      )
      Fabricate(
        :browser_pageview_event,
        url: "https://test.localhost/top",
        referrer: nil,
        created_at: "2026-05-12 10:01:00",
      )
      Fabricate(
        :browser_pageview_event,
        url: "https://test.localhost/latest",
        referrer: "https://test.localhost/t/topic/1",
        normalized_referrer: "test.localhost/t/topic/1",
        normalized_referrer_version: BrowserPageviewEventUrlNormalizer::REFERRER_VERSION,
        created_at: "2026-05-12 10:05:00",
      )
      Fabricate(
        :browser_pageview_event,
        url: "https://test.localhost/new",
        referrer: "https://alias.test.localhost/latest",
        normalized_referrer: "alias.test.localhost/latest",
        normalized_referrer_version: BrowserPageviewEventUrlNormalizer::REFERRER_VERSION,
        created_at: "2026-05-12 10:06:00",
      )

      described_class.aggregate(start_date: "2026-05-12".to_date, end_date: "2026-05-12".to_date)

      expect(described_class.pluck(:entry_url, :count)).to contain_exactly(
        ["/t/topic/#{topic.id}", 1],
        ["/top", 1],
      )
    end

    it "keeps subfolder paths distinct from root paths" do
      Discourse.stubs(:base_path).returns("/forum")
      topic = Fabricate(:topic)
      Fabricate(:browser_pageview_event, url: "/forum", created_at: "2026-05-12")
      Fabricate(
        :browser_pageview_event,
        topic_id: topic.id,
        url: "/forum/t/topic/#{topic.id}",
        created_at: "2026-05-12",
      )
      Fabricate(:browser_pageview_event, url: "/forum/latest", created_at: "2026-05-12")
      Fabricate(:browser_pageview_event, url: "/latest", created_at: "2026-05-12")

      described_class.aggregate(start_date: "2026-05-12".to_date, end_date: "2026-05-12".to_date)

      expect(described_class.order(:entry_url).pluck(:entry_url)).to eq(
        ["/forum", "/forum/latest", "/forum/t/topic/#{topic.id}", "/latest"],
      )
    end

    it "separates logged-in and likely crawler pageviews" do
      SiteSetting.improved_crawler_detection = true
      Fabricate(
        :browser_pageview_event,
        user_id: Fabricate(:user).id,
        score: CrawlerScorer::BOT_SCORE_THRESHOLD + 1,
        url: "/latest",
        created_at: "2026-05-12",
      )

      described_class.aggregate(start_date: "2026-05-12".to_date, end_date: "2026-05-12".to_date)

      expect(
        described_class.pick(
          :count,
          :logged_in_count,
          :likely_crawler_count,
          :likely_crawler_logged_in_count,
        ),
      ).to eq([1, 1, 1, 1])
    end

    it "preserves the oldest rollup when only a later retained event remains" do
      SiteSetting.clean_up_browser_pageview_events = true
      freeze_time(Time.zone.local(2026, 2, 15, 12, 0, 0))
      Fabricate(
        :browser_pageview_event,
        url: "https://test.localhost/top",
        created_at: "2026-02-13 23:59:00",
      )
      Fabricate(
        :browser_pageview_event,
        url: "https://test.localhost/latest",
        referrer: "https://test.localhost/top",
        normalized_referrer: "test.localhost/top",
        normalized_referrer_version: BrowserPageviewEventUrlNormalizer::REFERRER_VERSION,
        created_at: "2026-02-14 00:01:00",
      )
      described_class.aggregate(start_date: "2026-02-13".to_date, end_date: "2026-02-14".to_date)

      freeze_time(Time.zone.local(2026, 5, 14, 12, 0, 0))
      Jobs::CleanUpBrowserPageviewEvents.new.execute({})
      described_class.aggregate(start_date: "2026-02-13".to_date, end_date: "2026-02-14".to_date)

      expect(BrowserPageviewEvent.pluck(:created_at).map(&:to_date)).to eq(["2026-02-14".to_date])
      expect(described_class.pluck(:date, :entry_url)).to eq([["2026-02-13".to_date, "/top"]])
    end
  end

  describe ".recompute" do
    it "removes a historical entry when its referrer becomes internal" do
      date = "2026-05-12".to_date
      event = Fabricate(:browser_pageview_event, url: "/latest", created_at: date)
      described_class.aggregate(start_date: date, end_date: date)
      event.update_columns(
        referrer: "https://test.localhost/top",
        normalized_referrer: "test.localhost/top",
        normalized_referrer_version: BrowserPageviewEventUrlNormalizer::REFERRER_VERSION,
      )

      described_class.recompute([date, date])

      expect(described_class.all).to be_empty
    end
  end
end
