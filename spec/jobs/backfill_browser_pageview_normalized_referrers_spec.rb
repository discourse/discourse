# frozen_string_literal: true

RSpec.describe Jobs::BackfillBrowserPageviewNormalizedReferrers do
  subject(:job) { described_class.new }

  before { SiteSetting.persist_browser_pageview_events = true }

  describe "#execute" do
    it "normalizes historical rows using the inspector and stamps the current version" do
      raw = "https://www.reddit.com/r/discourse/"
      event = Fabricate(:browser_pageview_event_with_unnormalized_referrer, referrer: raw)

      job.execute({})

      expect(event.reload.normalized_referrer).to eq(
        BrowserPageviewReferrerInspector.normalize(raw),
      )
      expect(event.normalized_referrer_version).to eq(BrowserPageviewReferrerInspector::VERSION)
    end

    it "does nothing when persist_browser_pageview_events is disabled" do
      SiteSetting.persist_browser_pageview_events = false
      event =
        Fabricate(
          :browser_pageview_event_with_unnormalized_referrer,
          referrer: "https://reddit.com/",
        )

      job.execute({})

      expect(event.reload.normalized_referrer_version).to be_nil
    end

    it "leaves rows without a referrer untouched and does not let them block completion" do
      direct_visit = Fabricate(:browser_pageview_event_with_unnormalized_referrer, referrer: nil)
      referred =
        Fabricate(
          :browser_pageview_event_with_unnormalized_referrer,
          referrer: "https://reddit.com/",
        )

      job.execute({})

      expect(direct_visit.reload.normalized_referrer_version).to be_nil
      expect(referred.reload.normalized_referrer_version).to eq(
        BrowserPageviewReferrerInspector::VERSION,
      )
      expect { job.execute({}) }.not_to change { referred.reload.normalized_referrer_version }
    end

    it "processes an empty-string referrer once, normalizing it to NULL and stamping it" do
      event = Fabricate(:browser_pageview_event_with_unnormalized_referrer, referrer: "")

      job.execute({})

      event.reload
      expect(event.normalized_referrer).to be_nil
      expect(event.normalized_referrer_version).to eq(BrowserPageviewReferrerInspector::VERSION)
    end

    it "is a no-op once every referrer row is current" do
      Fabricate(:browser_pageview_event_with_unnormalized_referrer, referrer: "https://reddit.com/")
      job.execute({})

      expect { job.execute({}) }.not_to change {
        BrowserPageviewReferrerDailyRollup.pluck(:id, :count)
      }
    end

    it "only processes up to the configured batch size per run" do
      SiteSetting.browser_pageview_referrer_backfill_batch_size = 1
      Fabricate(:browser_pageview_event_with_unnormalized_referrer, referrer: "https://reddit.com/")
      Fabricate(
        :browser_pageview_event_with_unnormalized_referrer,
        referrer: "https://news.ycombinator.com/",
      )

      job.execute({})

      expect(BrowserPageviewEvent.where(normalized_referrer_version: nil).count).to eq(1)
    end

    it "skips rows older than the retention cutoff when cleanup is enabled" do
      SiteSetting.clean_up_browser_pageview_events = true
      prunable =
        Fabricate(
          :browser_pageview_event_with_unnormalized_referrer,
          referrer: "https://www.reddit.com/",
          created_at: (Jobs::CleanUpBrowserPageviewEvents::RETENTION_PERIOD + 1.day).ago,
        )
      recent =
        Fabricate(
          :browser_pageview_event_with_unnormalized_referrer,
          referrer: "https://www.reddit.com/",
        )

      job.execute({})

      prunable.reload
      expect(prunable.normalized_referrer).to be_nil
      expect(prunable.normalized_referrer_version).to be_nil
      expect(recent.reload.normalized_referrer_version).to eq(
        BrowserPageviewReferrerInspector::VERSION,
      )
    end

    it "backfills rows older than the retention period when cleanup is disabled" do
      SiteSetting.clean_up_browser_pageview_events = false
      event =
        Fabricate(
          :browser_pageview_event_with_unnormalized_referrer,
          referrer: "https://www.reddit.com/",
          created_at: (Jobs::CleanUpBrowserPageviewEvents::RETENTION_PERIOD + 1.day).ago,
        )

      job.execute({})

      expect(event.reload.normalized_referrer_version).to eq(
        BrowserPageviewReferrerInspector::VERSION,
      )
    end

    it "repairs the affected rollups to match a fresh aggregation, including the NULL bucket" do
      date = 3.days.ago.to_date
      Fabricate(
        :browser_pageview_event_with_unnormalized_referrer,
        referrer: "https://www.google.com/",
        created_at: date,
      )
      Fabricate(
        :browser_pageview_event_with_unnormalized_referrer,
        referrer: "https://www.google.com/",
        created_at: date,
      )
      Fabricate(:browser_pageview_event_with_unnormalized_referrer, referrer: nil, created_at: date)

      job.execute({})

      rollups = BrowserPageviewReferrerDailyRollup.where(date:).pluck(:normalized_referrer, :count)
      expect(rollups).to contain_exactly(["google.com", 2], [nil, 1])
    end

    it "surfaces backfilled referrers in the historical top-referrers report" do
      Discourse.stubs(:current_hostname).returns("forum.example.com")
      start_date = 7.days.ago.to_date
      created_at = 3.days.ago
      3.times do
        Fabricate(
          :browser_pageview_event_with_unnormalized_referrer,
          referrer: "https://news.ycombinator.com/item?id=1",
          created_at:,
        )
      end
      Fabricate(
        :browser_pageview_event_with_unnormalized_referrer,
        referrer: "https://www.reddit.com/r/discourse",
        created_at:,
      )

      job.execute({})

      report =
        Report.find(
          "top_referrers_by_browser_pageviews",
          start_date: start_date,
          end_date: Date.current,
        )
      expect(report.data.map { |row| row[:normalized_referrer] }).to eq(
        %w[news.ycombinator.com/item?id=1 reddit.com/r/discourse],
      )
    end

    it "re-selects the row and repairs the rollup when a crash happens before the version is stamped" do
      date = 3.days.ago.to_date
      event =
        Fabricate(
          :browser_pageview_event_with_unnormalized_referrer,
          referrer: "https://www.google.com/",
          created_at: date,
        )

      BrowserPageviewReferrerDailyRollup.stubs(:recompute).raises("rollup boom")
      expect { job.execute({}) }.to raise_error("rollup boom")

      expect(event.reload.normalized_referrer).to eq("google.com")
      expect(event.normalized_referrer_version).to be_nil
      expect(BrowserPageviewReferrerDailyRollup.where(date:)).to be_empty

      BrowserPageviewReferrerDailyRollup.unstub(:recompute)
      job.execute({})

      expect(event.reload.normalized_referrer_version).to eq(
        BrowserPageviewReferrerInspector::VERSION,
      )
      expect(BrowserPageviewReferrerDailyRollup.where(date:).sum(:count)).to eq(1)
    end

    it "re-normalizes rows stamped with an older version and repairs their rollups" do
      date = 3.days.ago.to_date
      raw = "https://google.com/?utm_source=newsletter"
      event =
        Fabricate(
          :browser_pageview_event,
          referrer: raw,
          normalized_referrer: "google.com/?utm_source=newsletter",
          normalized_referrer_version: BrowserPageviewReferrerInspector::VERSION,
          created_at: date,
        )

      stub_const(
        BrowserPageviewReferrerInspector,
        "VERSION",
        BrowserPageviewReferrerInspector::VERSION + 1,
      ) do
        job.execute({})

        event.reload
        expect(event.normalized_referrer).to eq(BrowserPageviewReferrerInspector.normalize(raw))
        expect(event.normalized_referrer_version).to eq(BrowserPageviewReferrerInspector::VERSION)
      end

      expect(BrowserPageviewReferrerDailyRollup.where(date:).pluck(:normalized_referrer)).to eq(
        ["google.com"],
      )
    end
  end
end
