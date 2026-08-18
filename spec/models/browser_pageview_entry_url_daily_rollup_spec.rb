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
    def aggregate(start_date: "2026-05-12", end_date: start_date)
      described_class.aggregate(start_date: start_date.to_date, end_date: end_date.to_date)
    end

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

      aggregate

      expect(described_class.order(:entry_url).pluck(:entry_url, :count)).to eq(
        [["/t/#{topic.slug}/#{topic.id}", 1], ["/top", 1]],
      )
    end

    it "allows only reviewed public route families" do
      safe_paths = %w[/ /tags /latest /top /new /categories /faq /guidelines /about /groups /badges]
      unsafe_paths = %w[
        /search
        /unread
        /associate/token
        /session/email-login/token
        /u/password-reset/token
        /c/private-category/2
        /tag/restricted
        /g/hidden-team
        /g/hidden-team/messages
        /unknown-plugin
      ]

      (safe_paths + unsafe_paths).each do |path|
        Fabricate(
          :browser_pageview_event,
          url: "https://test.localhost#{path}",
          created_at: "2026-05-12",
        )
      end

      aggregate

      expect(described_class.pluck(:entry_url)).to contain_exactly(*safe_paths)
    end

    it "allows reviewed routes beneath the configured subfolder" do
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

      aggregate

      expect(described_class.order(:entry_url).pluck(:entry_url)).to eq(
        ["/forum", "/forum/latest", "/forum/t/#{topic.slug}/#{topic.id}"],
      )
    end

    it "includes public topics but excludes private messages and restricted topics" do
      public_topic = Fabricate(:topic)
      private_message = Fabricate(:private_message_topic)
      restricted_category = Fabricate(:private_category, group: Fabricate(:group))
      restricted_topic = Fabricate(:topic, category: restricted_category)

      [public_topic, private_message, restricted_topic].each do |topic|
        Fabricate(
          :browser_pageview_event,
          topic_id: topic.id,
          url: "/t/confidential-#{topic.id}/#{topic.id}",
          created_at: "2026-05-12",
        )
      end

      aggregate

      expect(described_class.pluck(:entry_url)).to eq(
        ["/t/#{public_topic.slug}/#{public_topic.id}"],
      )
    end

    it "preserves login and crawler classification in the daily rollup" do
      SiteSetting.improved_crawler_detection = true
      Fabricate(
        :browser_pageview_event,
        user_id: Fabricate(:user).id,
        score: CrawlerScorer::BOT_SCORE_THRESHOLD + 1,
        url: "/latest",
        created_at: "2026-05-12",
      )

      aggregate

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
      aggregate(start_date: "2026-02-13", end_date: "2026-02-14")

      freeze_time(Time.zone.local(2026, 5, 14, 12, 0, 0))
      Jobs::CleanUpBrowserPageviewEvents.new.execute({})
      aggregate(start_date: "2026-02-13", end_date: "2026-02-14")

      expect(BrowserPageviewEvent.pluck(:created_at).map(&:to_date)).to eq(["2026-02-14".to_date])
      expect(described_class.pluck(:date, :entry_url)).to eq([["2026-02-13".to_date, "/top"]])
    end
  end

  describe ".recompute" do
    it "rebuilds each affected date from its retained events" do
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

  describe "full rebuild tracking" do
    it "records only the latest completed full rebuild without creating report data" do
      described_class.mark_full_rebuild(date: "2026-05-12")
      described_class.mark_full_rebuild(date: "2026-05-14")

      expect(described_class.last_full_rebuild_date).to eq("2026-05-14".to_date)
      expect(described_class.pluck(:date, :entry_url, :count)).to eq(
        [["2026-05-14".to_date, nil, 0]],
      )
    end
  end
end
