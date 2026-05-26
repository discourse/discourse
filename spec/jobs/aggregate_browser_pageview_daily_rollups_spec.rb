# frozen_string_literal: true

RSpec.describe Jobs::AggregateBrowserPageviewDailyRollups do
  before { Discourse.stubs(:current_hostname).returns("forum.example.com") }

  it "does nothing when persist_browser_pageview_events is disabled" do
    SiteSetting.persist_browser_pageview_events = false
    Fabricate(:browser_pageview_event, country_code: "US", normalized_referrer: "google.com")

    expect { described_class.new.execute({}) }.not_to change {
      BrowserPageviewCountryDailyRollup.count + BrowserPageviewReferrerDailyRollup.count
    }
  end

  it "aggregates both country and referrer rollups from recent pageview events" do
    SiteSetting.persist_browser_pageview_events = true
    Fabricate(:browser_pageview_event, country_code: "US", normalized_referrer: "google.com")

    described_class.new.execute({})

    expect(BrowserPageviewCountryDailyRollup.where(country_code: "US").sum(:count)).to eq(1)
    expect(
      BrowserPageviewReferrerDailyRollup.where(normalized_referrer: "google.com").sum(:count),
    ).to eq(1)
  end

  it "backfills from the earliest event date on the first run when rollups are empty" do
    SiteSetting.persist_browser_pageview_events = true
    Fabricate(:browser_pageview_event, country_code: "US", created_at: 60.days.ago)
    Fabricate(:browser_pageview_event, country_code: "GB", created_at: 5.days.ago)

    described_class.new.execute({})

    expect(BrowserPageviewCountryDailyRollup.pluck(:country_code)).to contain_exactly("US", "GB")
  end

  it "clears the report cache after running so stale empty results do not linger" do
    SiteSetting.persist_browser_pageview_events = true
    Fabricate(:browser_pageview_event, country_code: "US")
    Report.expects(:clear_cache).with("top_countries_by_browser_pageviews").once
    Report.expects(:clear_cache).with("top_referrers_by_browser_pageviews").once

    described_class.new.execute({})
  end

  it "only aggregates yesterday and today once historical rollups are populated" do
    SiteSetting.persist_browser_pageview_events = true
    Fabricate(:browser_pageview_event, country_code: "US", created_at: 60.days.ago)
    described_class.new.execute({}) # first run backfills everything

    Fabricate(:browser_pageview_event, country_code: "GB", created_at: 60.days.ago) # late old event
    Fabricate(:browser_pageview_event, country_code: "FR") # today
    described_class.new.execute({}) # second run only does yesterday + today

    expect(BrowserPageviewCountryDailyRollup.pluck(:country_code)).to contain_exactly("US", "FR")
  end
end
