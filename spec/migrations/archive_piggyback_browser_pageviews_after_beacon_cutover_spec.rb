# frozen_string_literal: true

require Rails.root.join(
          "db/migrate/20260910030427_archive_piggyback_browser_pageviews_after_beacon_cutover.rb",
        )

RSpec.describe ArchivePiggybackBrowserPageviewsAfterBeaconCutover do
  before do
    DB.exec(
      "ALTER TABLE browser_pageview_events DISABLE TRIGGER skip_piggyback_browser_pageview_events",
    )
  end

  after do
    DB.exec(
      "ALTER TABLE browser_pageview_events ENABLE TRIGGER skip_piggyback_browser_pageview_events",
    )
  end

  def legacy_event(created_at)
    event = Fabricate(:browser_pageview_event, created_at:)
    DB.exec("UPDATE browser_pageview_events SET source = 1 WHERE id = :id", id: event.id)
    event
  end

  it "archives unmatched piggybacks from midnight after the first partial beacon day" do
    first_day = Date.new(2026, 8, 20)
    ApplicationRequest.create!(date: first_day, req_type: :page_view_anon_browser_beacon, count: 10)
    ApplicationRequest.create!(date: first_day, req_type: :page_view_anon_browser, count: 20)
    historical = legacy_event(Time.utc(2026, 8, 19))
    partial_day = legacy_event(Time.utc(2026, 8, 20, 23, 59, 59))
    boundary = legacy_event(Time.utc(2026, 8, 21))
    later = legacy_event(Time.utc(2026, 8, 22))
    beacon = Fabricate(:browser_pageview_event, created_at: later.created_at)
    score = BrowserPageviewEventScore.create!(event_id: boundary.id, velocity_score: 42)
    historical_score = BrowserPageviewEventScore.create!(event_id: historical.id)
    event_data =
      DB.query_single(
        "SELECT to_jsonb(events) FROM browser_pageview_events events WHERE id IN (:ids) ORDER BY id",
        ids: [boundary.id, later.id],
      )
    score_data =
      DB.query_single(
        "SELECT to_jsonb(scores) FROM browser_pageview_event_scores scores WHERE id = :id",
        id: score.id,
      )

    stub_const(described_class, "BATCH_SIZE", 1) { described_class.new.up }
    described_class.new.up

    expect(BrowserPageviewEvent.pluck(:id)).to contain_exactly(
      historical.id,
      partial_day.id,
      beacon.id,
    )
    expect(BrowserPageviewEventScore.pluck(:id)).to contain_exactly(historical_score.id)
    expect(
      DB.query_single(
        "SELECT to_jsonb(events) FROM browser_pageview_events_backup events ORDER BY id",
      ),
    ).to eq(event_data)
    expect(
      DB.query_single("SELECT to_jsonb(scores) FROM browser_pageview_event_scores_backup scores"),
    ).to eq(score_data)
  end

  it "uses the first positive beacon day when legacy counters on that day are zero" do
    first_day = Date.new(2026, 8, 20)
    ApplicationRequest.create!(
      date: first_day - 1,
      req_type: :page_view_anon_browser_beacon,
      count: 0,
    )
    ApplicationRequest.create!(
      date: first_day,
      req_type: :page_view_logged_in_browser_beacon,
      count: 1,
    )
    ApplicationRequest.create!(date: first_day, req_type: :page_view_logged_in_browser, count: 0)
    historical = legacy_event(Time.utc(2026, 8, 19, 23, 59, 59))
    boundary = legacy_event(Time.utc(2026, 8, 20))

    described_class.new.up

    expect(BrowserPageviewEvent.pluck(:id)).to eq([historical.id])
    expect(DB.query_single("SELECT id FROM browser_pageview_events_backup")).to eq([boundary.id])
  end

  it "preserves all piggybacks when no positive beacon counters exist" do
    ApplicationRequest.create!(
      date: Date.new(2026, 8, 20),
      req_type: :page_view_anon_browser_beacon,
      count: 0,
    )
    legacy = legacy_event(Time.utc(2026, 8, 21))

    described_class.new.up

    expect(BrowserPageviewEvent.pluck(:id)).to eq([legacy.id])
    expect(DB.query_single("SELECT id FROM browser_pageview_events_backup")).to be_empty
  end

  it "rolls back the whole batch if a score cannot be backed up" do
    ApplicationRequest.create!(
      date: Date.new(2026, 8, 20),
      req_type: :page_view_anon_browser_beacon,
      count: 1,
    )
    legacy = legacy_event(Time.utc(2026, 8, 21))
    score = BrowserPageviewEventScore.create!(event_id: legacy.id)
    DB.exec(
      "INSERT INTO browser_pageview_event_scores_backup SELECT * FROM browser_pageview_event_scores",
    )

    expect do
      BrowserPageviewEvent.transaction(requires_new: true) { described_class.new.up }
    end.to raise_error(PG::UniqueViolation)

    expect(BrowserPageviewEvent.pluck(:id)).to eq([legacy.id])
    expect(BrowserPageviewEventScore.pluck(:id)).to eq([score.id])
    expect(DB.query_single("SELECT id FROM browser_pageview_events_backup")).to be_empty
  end
end
