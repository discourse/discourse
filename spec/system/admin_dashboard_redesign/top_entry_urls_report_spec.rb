# frozen_string_literal: true

RSpec.describe "Top entry URLs report" do
  let(:admin) { Fabricate(:admin) }
  let(:report_page) { PageObjects::Pages::AdminReport.new }

  before do
    SiteSetting.persist_browser_pageview_events = true
    SiteSetting.use_legacy_pageviews = false
    sign_in(admin)
  end

  it "lets an admin open an entry URL from the report" do
    BrowserPageviewEntryUrlDailyRollup.create!(
      date: Time.zone.today,
      entry_url: "/latest",
      count: 2,
      logged_in_count: 0,
      likely_crawler_count: 0,
      likely_crawler_logged_in_count: 0,
    )

    report_page.visit_report("top_entry_urls")

    expect(report_page).to have_rendered_report("top_entry_urls")
    expect(report_page).to have_report_link(text: "/latest", href: "/latest")
  end
end
