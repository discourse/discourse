# frozen_string_literal: true

RSpec.describe Jobs::MaintainBrowserPageviewSessionRollups do
  include BrowserPageviewSessionHelpers

  subject(:job) { described_class.new }

  before { SiteSetting.persist_browser_pageview_events = true }

  describe "#execute" do
    it "does nothing when persist_browser_pageview_events is disabled" do
      SiteSetting.persist_browser_pageview_events = false
      Fabricate(:browser_pageview_event)

      job.execute({})

      expect(BrowserPageviewSessionDailyRollup.count).to eq(0)
    end

    it "aggregates session rollups (bounce and duration) from recent pageview events" do
      today = Time.zone.now.beginning_of_day

      Fabricate(:browser_pageview_event, created_at: today + 1.hour)

      engaged_visit_start = Fabricate(:browser_pageview_event, created_at: today + 2.hours)
      Fabricate(
        :browser_pageview_event,
        session_id: engaged_visit_start.session_id,
        created_at: today + 2.hours + 40.seconds,
      )

      job.execute({})

      expect(
        BrowserPageviewSessionDailyRollup.pluck(
          :date,
          :logged_in,
          :sessions_count,
          :bounced_count,
          :total_duration_seconds,
        ),
      ).to eq([[Date.current, false, 2, 1, 40]])
    end

    it "backfills from the instrumentation date on the first run, skipping older retained events" do
      set_engagements_instrumented_at(2.days.ago)
      Fabricate(:browser_pageview_event, created_at: 5.days.ago)
      Fabricate(:browser_pageview_event, created_at: 1.day.ago)

      job.execute({})

      expect(BrowserPageviewSessionDailyRollup.pluck(:date)).to contain_exactly(1.day.ago.to_date)
    end

    it "never rolls up days before exit pings could have been recorded" do
      set_engagements_instrumented_at(Time.zone.now)
      Fabricate(:browser_pageview_event, created_at: 1.day.ago)
      Fabricate(:browser_pageview_event, created_at: 1.hour.ago)

      job.execute({})

      expect(BrowserPageviewSessionDailyRollup.pluck(:date)).to contain_exactly(Date.current)
    end

    it "only aggregates yesterday and today once historical rollups are populated" do
      set_engagements_instrumented_at(10.days.ago)
      Fabricate(:browser_pageview_event, created_at: 5.days.ago)
      job.execute({}) # first run backfills from the instrumentation date

      Fabricate(:browser_pageview_event, created_at: 4.days.ago) # late event behind the window
      Fabricate(:browser_pageview_event) # today
      job.execute({}) # second run only does yesterday + today

      expect(BrowserPageviewSessionDailyRollup.pluck(:date)).to contain_exactly(
        5.days.ago.to_date,
        Date.current,
      )
    end
  end
end
