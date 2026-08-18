# frozen_string_literal: true

RSpec.describe BrowserPageviewEntryUrlDailyRollup do
  before { freeze_time(Time.zone.local(2026, 5, 14, 12, 0, 0)) }

  def aggregate(start_date: "2026-05-12", end_date: start_date)
    described_class.aggregate(start_date: start_date.to_date, end_date: end_date.to_date)
  end

  it "attributes each session to its earliest safe entry and records covered dates" do
    Fabricate(
      :browser_pageview_event,
      session_id: "topic-session",
      url: "https://test.localhost/t/topic/1?utm_source=email#post_1",
      created_at: "2026-05-12 10:00:00",
    )
    Fabricate(
      :browser_pageview_event,
      session_id: "topic-session",
      url: "https://test.localhost/latest",
      created_at: "2026-05-12 10:05:00",
    )
    Fabricate(
      :browser_pageview_event,
      session_id: "search-session",
      url: "https://test.localhost/search?q=secret",
      created_at: "2026-05-12 11:00:00",
    )
    Fabricate(
      :browser_pageview_event,
      session_id: "search-session",
      url: "https://test.localhost/t/not-a-fallback/2",
      created_at: "2026-05-12 11:05:00",
    )

    aggregate

    expect(described_class.pluck(:entry_url, :count)).to eq([["/t/topic/1", 1]])
    expect(BrowserPageviewEntryUrlSession.find_by(session_id: "search-session").entry_url).to be_nil
    expect(BrowserPageviewEntryUrlDailyRollupDate.pluck(:date)).to eq(["2026-05-12".to_date])
  end

  it "allows only reviewed public route families" do
    safe_paths = %w[
      /
      /t/topic/1
      /c/support/2
      /tag/ruby
      /tags
      /g/team
      /latest
      /top
      /new
      /categories
      /faq
      /guidelines
      /about
      /groups
      /badges
    ]
    unsafe_paths = %w[
      /search
      /unread
      /associate/token
      /session/email-login/token
      /u/password-reset/token
      /unknown-plugin
    ]

    (safe_paths + unsafe_paths).each_with_index do |path, index|
      Fabricate(
        :browser_pageview_event,
        session_id: "session-#{index}",
        url: "https://test.localhost#{path}",
        created_at: "2026-05-12",
      )
    end

    aggregate

    expect(described_class.order(:entry_url).pluck(:entry_url)).to eq(safe_paths.sort)
  end

  it "moves attribution to an earlier event that commits after the initial rollup" do
    Fabricate(
      :browser_pageview_event,
      session_id: "out-of-order-session",
      url: "https://test.localhost/latest",
      created_at: "2026-05-12 00:01:00",
    )
    aggregate

    Fabricate(
      :browser_pageview_event,
      session_id: "out-of-order-session",
      url: "https://test.localhost/top",
      created_at: "2026-05-11 23:59:00",
    )
    aggregate(start_date: "2026-05-11", end_date: "2026-05-12")

    expect(described_class.pluck(:date, :entry_url, :count)).to eq(
      [["2026-05-11".to_date, "/top", 1]],
    )
  end

  it "preserves a cross-midnight attribution while source events and the ledger expire" do
    SiteSetting.clean_up_browser_pageview_events = true
    freeze_time(Time.zone.local(2026, 2, 15, 12, 0, 0))
    Fabricate(
      :browser_pageview_event,
      session_id: "cross-midnight-session",
      url: "https://test.localhost/top",
      created_at: "2026-02-13 23:59:00",
    )
    Fabricate(
      :browser_pageview_event,
      session_id: "cross-midnight-session",
      url: "https://test.localhost/latest",
      created_at: "2026-02-14 00:01:00",
    )
    aggregate(start_date: "2026-02-13", end_date: "2026-02-14")

    freeze_time(Time.zone.local(2026, 5, 14, 12, 0, 0))
    Jobs::CleanUpBrowserPageviewEvents.new.execute({})
    aggregate(start_date: "2026-02-14")

    expect(BrowserPageviewEntryUrlSession.pluck(:entry_url)).to eq(["/top"])
    expect(described_class.pluck(:date, :entry_url)).to eq([["2026-02-13".to_date, "/top"]])

    freeze_time(Time.zone.local(2026, 5, 15, 12, 0, 0))
    Jobs::CleanUpBrowserPageviewEvents.new.execute({})

    expect(BrowserPageviewEntryUrlSession.all).to be_empty
    expect(described_class.pluck(:date, :entry_url)).to eq([["2026-02-13".to_date, "/top"]])
  end
end
