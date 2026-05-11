# frozen_string_literal: true

RSpec.describe Jobs::CleanUpBrowserPageviewEvents do
  fab!(:fresh_event) do
    BrowserPageviewEvent.create!(
      url: "/t/topic/1",
      ip_address: "1.2.3.4",
      user_agent: "Firefox",
      session_id: "abc",
      created_at: 1.month.ago,
    )
  end

  fab!(:old_event) do
    BrowserPageviewEvent.create!(
      url: "/t/topic/2",
      ip_address: "1.2.3.4",
      user_agent: "Firefox",
      session_id: "def",
      created_at: 4.months.ago,
    )
  end

  it "does nothing when the site setting is disabled" do
    SiteSetting.clean_up_browser_pageview_events = false

    expect { described_class.new.execute({}) }.not_to change { BrowserPageviewEvent.count }
  end

  it "deletes events older than 3 months and keeps fresher ones" do
    SiteSetting.clean_up_browser_pageview_events = true

    expect { described_class.new.execute({}) }.to change { BrowserPageviewEvent.count }.by(-1)
    expect(BrowserPageviewEvent.all).to contain_exactly(fresh_event)
  end
end
