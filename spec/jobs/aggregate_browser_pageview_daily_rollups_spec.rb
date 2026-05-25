# frozen_string_literal: true

RSpec.describe Jobs::AggregateBrowserPageviewDailyRollups do
  it "does nothing when persist_browser_pageview_events is disabled" do
    SiteSetting.persist_browser_pageview_events = false
    Fabricate(:browser_pageview_event, country_code: "US", normalized_referrer: "google.com")

    expect { described_class.new.execute({}) }.not_to change {
      BrowserPageviewCountryDailyRollup.count + BrowserPageviewReferrerDailyRollup.count
    }
  end

  it "aggregates both country and referrer rollups from recent pageview events" do
    SiteSetting.persist_browser_pageview_events = true
    Discourse.stubs(:current_hostname).returns("forum.example.com")
    Fabricate(:browser_pageview_event, country_code: "US", normalized_referrer: "google.com")

    described_class.new.execute({})

    expect(BrowserPageviewCountryDailyRollup.where(country_code: "US").sum(:count)).to eq(1)
    expect(
      BrowserPageviewReferrerDailyRollup.where(normalized_referrer: "google.com").sum(:count),
    ).to eq(1)
  end
end
