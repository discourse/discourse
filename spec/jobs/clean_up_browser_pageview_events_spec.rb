# frozen_string_literal: true

RSpec.describe Jobs::CleanUpBrowserPageviewEvents do
  it "does nothing when the site setting is disabled" do
    SiteSetting.clean_up_browser_pageview_events = false
    Fabricate(:browser_pageview_event, created_at: 4.months.ago)
    Fabricate(:browser_pageview_event, created_at: 1.month.ago)

    expect { described_class.new.execute({}) }.not_to change { BrowserPageviewEvent.count }
  end

  it "deletes events older than 3 months and keeps fresher ones" do
    SiteSetting.clean_up_browser_pageview_events = true
    fresh_event = Fabricate(:browser_pageview_event, created_at: 1.month.ago)
    Fabricate(:browser_pageview_event, created_at: 4.months.ago)

    expect { described_class.new.execute({}) }.to change { BrowserPageviewEvent.count }.by(-1)
    expect(BrowserPageviewEvent.all).to contain_exactly(fresh_event)
  end

  it "deletes session engagements older than 3 months and keeps fresher ones" do
    SiteSetting.clean_up_browser_pageview_events = true
    fresh = BrowserPageviewSessionEngagement.create!(session_id: "fresh", created_at: 1.month.ago)
    BrowserPageviewSessionEngagement.create!(session_id: "old", created_at: 4.months.ago)

    expect { described_class.new.execute({}) }.to change {
      BrowserPageviewSessionEngagement.count
    }.by(-1)
    expect(BrowserPageviewSessionEngagement.all).to contain_exactly(fresh)
  end

  it "keeps all events on the retention cutoff day" do
    SiteSetting.clean_up_browser_pageview_events = true

    freeze_time Time.zone.local(2026, 5, 28, 12, 30) do
      cutoff_day_start = 3.months.ago.beginning_of_day
      cutoff_day_end = 3.months.ago.end_of_day

      Fabricate(:browser_pageview_event, created_at: cutoff_day_start - 1.second)
      cutoff_day_first_event = Fabricate(:browser_pageview_event, created_at: cutoff_day_start)
      cutoff_day_last_event = Fabricate(:browser_pageview_event, created_at: cutoff_day_end)

      described_class.new.execute({})

      expect(BrowserPageviewEvent.all).to contain_exactly(
        cutoff_day_first_event,
        cutoff_day_last_event,
      )
    end
  end
end
