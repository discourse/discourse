# frozen_string_literal: true

RSpec.describe Jobs::MaintainBrowserPageviewRollups do
  subject(:job) { described_class.new }

  before { SiteSetting.persist_browser_pageview_events = true }

  describe "#execute" do
    it "does nothing when persist_browser_pageview_events is disabled" do
      SiteSetting.persist_browser_pageview_events = false
      event =
        Fabricate(
          :browser_pageview_event_with_unnormalized_referrer,
          referrer: "https://reddit.com/",
          country_code: "US",
        )

      job.execute({})

      expect(BrowserPageviewCountryDailyRollup.count).to eq(0)
      expect(BrowserPageviewReferrerDailyRollup.count).to eq(0)
      expect(event.reload.normalized_referrer_version).to be_nil
    end

    context "when aggregating rollups" do
      it "aggregates both country and referrer rollups from recent pageview events" do
        Fabricate(:browser_pageview_event, country_code: "US", normalized_referrer: "google.com")

        job.execute({})

        expect(BrowserPageviewCountryDailyRollup.where(country_code: "US").sum(:count)).to eq(1)
        expect(
          BrowserPageviewReferrerDailyRollup.where(normalized_referrer: "google.com").sum(:count),
        ).to eq(1)
      end

      it "uses beacon source for rollups when dashboard_improvements is enabled" do
        SiteSetting.dashboard_improvements = false
        Fabricate(
          :browser_pageview_event,
          country_code: "US",
          normalized_referrer: "google.com",
          source: BrowserPageviewEvent::SOURCE_PIGGYBACK,
        )
        Fabricate(
          :browser_pageview_event,
          country_code: "GB",
          normalized_referrer: "reddit.com",
          source: BrowserPageviewEvent::SOURCE_BEACON,
        )

        job.execute({})

        expect(BrowserPageviewCountryDailyRollup.pluck(:country_code, :count)).to eq([["US", 1]])
        expect(BrowserPageviewReferrerDailyRollup.pluck(:normalized_referrer, :count)).to eq(
          [["google.com", 1]],
        )

        SiteSetting.dashboard_improvements = true
        job.execute({})

        expect(BrowserPageviewCountryDailyRollup.pluck(:country_code, :count)).to contain_exactly(
          ["US", 1],
          ["GB", 1],
        )
        expect(
          BrowserPageviewReferrerDailyRollup.pluck(:normalized_referrer, :count),
        ).to contain_exactly(["google.com", 1], ["reddit.com", 1])
      end

      it "backfills from the earliest event date on the first run when rollups are empty" do
        Fabricate(:browser_pageview_event, country_code: "US", created_at: 60.days.ago)
        Fabricate(:browser_pageview_event, country_code: "GB", created_at: 5.days.ago)

        job.execute({})

        expect(BrowserPageviewCountryDailyRollup.pluck(:country_code)).to contain_exactly(
          "US",
          "GB",
        )
      end

      it "only aggregates yesterday and today once historical rollups are populated" do
        Fabricate(:browser_pageview_event, country_code: "US", created_at: 60.days.ago)
        job.execute({}) # first run backfills everything

        Fabricate(:browser_pageview_event, country_code: "GB", created_at: 60.days.ago) # late old event
        Fabricate(:browser_pageview_event, country_code: "FR") # today
        job.execute({}) # second run only does yesterday + today

        expect(BrowserPageviewCountryDailyRollup.pluck(:country_code)).to contain_exactly(
          "US",
          "FR",
        )
      end
    end

    context "when backfilling referrers" do
      it "normalizes historical rows using the inspector and stamps the current version" do
        raw = "https://www.reddit.com/r/discourse/"
        event = Fabricate(:browser_pageview_event_with_unnormalized_referrer, referrer: raw)

        job.execute({})

        expect(event.reload.normalized_referrer).to eq(
          BrowserPageviewReferrerInspector.normalize(raw),
        )
        expect(event.normalized_referrer_version).to eq(BrowserPageviewReferrerInspector::VERSION)
      end

      it "only backfills referrers from the active source" do
        SiteSetting.dashboard_improvements = true
        piggyback_event =
          Fabricate(
            :browser_pageview_event_with_unnormalized_referrer,
            referrer: "https://www.google.com/",
            source: BrowserPageviewEvent::SOURCE_PIGGYBACK,
          )
        beacon_event =
          Fabricate(
            :browser_pageview_event_with_unnormalized_referrer,
            referrer: "https://www.reddit.com/",
            source: BrowserPageviewEvent::SOURCE_BEACON,
          )

        job.execute({})

        expect(piggyback_event.reload.normalized_referrer_version).to be_nil
        expect(beacon_event.reload.normalized_referrer).to eq("reddit.com")
        expect(beacon_event.normalized_referrer_version).to eq(
          BrowserPageviewReferrerInspector::VERSION,
        )
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
        Fabricate(
          :browser_pageview_event_with_unnormalized_referrer,
          referrer: "https://reddit.com/",
        )
        job.execute({})

        expect { job.execute({}) }.not_to change {
          BrowserPageviewReferrerDailyRollup.pluck(:id, :count)
        }
      end

      it "only processes up to the configured batch size per run" do
        SiteSetting.browser_pageview_referrer_backfill_batch_size = 1
        Fabricate(
          :browser_pageview_event_with_unnormalized_referrer,
          referrer: "https://reddit.com/",
        )
        Fabricate(
          :browser_pageview_event_with_unnormalized_referrer,
          referrer: "https://news.ycombinator.com/",
        )

        job.execute({})

        expect(BrowserPageviewEvent.where(normalized_referrer_version: nil).count).to eq(1)
      end

      it "waits to repair a date until every stale referrer row for that date is processed" do
        SiteSetting.browser_pageview_referrer_backfill_batch_size = 1
        date = 3.days.ago.to_date
        2.times do
          Fabricate(
            :browser_pageview_event_with_unnormalized_referrer,
            referrer: "https://www.google.com/",
            created_at: date,
          )
        end

        job.execute({})

        rollups =
          BrowserPageviewReferrerDailyRollup.where(date:).pluck(:normalized_referrer, :count)
        expect(rollups).to eq([[nil, 2]])

        job.execute({})

        rollups =
          BrowserPageviewReferrerDailyRollup.where(date:).pluck(:normalized_referrer, :count)
        expect(rollups).to eq([["google.com", 2]])
      end

      it "skips rows within a day of the retention cutoff when cleanup is enabled" do
        SiteSetting.clean_up_browser_pageview_events = true
        prunable =
          Fabricate(
            :browser_pageview_event_with_unnormalized_referrer,
            referrer: "https://www.reddit.com/",
            created_at: (BrowserPageviewEvent::RETENTION_PERIOD + 1.day).ago,
          )
        near_cutoff =
          Fabricate(
            :browser_pageview_event_with_unnormalized_referrer,
            referrer: "https://www.reddit.com/",
            created_at: BrowserPageviewEvent::RETENTION_PERIOD.ago,
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
        expect(near_cutoff.reload.normalized_referrer_version).to be_nil
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
            created_at: (BrowserPageviewEvent::RETENTION_PERIOD + 1.day).ago,
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
        Fabricate(
          :browser_pageview_event_with_unnormalized_referrer,
          referrer: nil,
          created_at: date,
        )

        job.execute({})

        rollups =
          BrowserPageviewReferrerDailyRollup.where(date:).pluck(:normalized_referrer, :count)
        expect(rollups).to contain_exactly(["google.com", 2], [nil, 1])
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
        expect(
          BrowserPageviewReferrerDailyRollup.where(date:).pluck(:normalized_referrer, :count),
        ).to eq([[nil, 1]])

        BrowserPageviewReferrerDailyRollup.unstub(:recompute)
        job.execute({})

        expect(event.reload.normalized_referrer_version).to eq(
          BrowserPageviewReferrerInspector::VERSION,
        )
        expect(
          BrowserPageviewReferrerDailyRollup.where(date:).pluck(:normalized_referrer, :count),
        ).to eq([["google.com", 1]])
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
end
