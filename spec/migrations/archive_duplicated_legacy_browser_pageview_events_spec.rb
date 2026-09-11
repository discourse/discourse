# frozen_string_literal: true

require Rails.root.join(
          "db/migrate/20260910030404_archive_duplicated_legacy_browser_pageview_events.rb",
        )

RSpec.describe ArchiveDuplicatedLegacyBrowserPageviewEvents do
  before do
    @original_verbose = ActiveRecord::Migration.verbose
    ActiveRecord::Migration.verbose = false
    DB.exec(
      "ALTER TABLE browser_pageview_events DISABLE TRIGGER skip_piggyback_browser_pageview_events",
    )
  end

  after do
    DB.exec(
      "ALTER TABLE browser_pageview_events ENABLE TRIGGER skip_piggyback_browser_pageview_events",
    )
    ActiveRecord::Migration.verbose = @original_verbose
  end

  it "archives duplicated legacy events after batches without matches" do
    standalone_legacy = Fabricate(:browser_pageview_event, session_id: "legacy-session")
    another_standalone_legacy =
      Fabricate(:browser_pageview_event, session_id: "another-legacy-session")
    duplicated_legacy = Fabricate(:browser_pageview_event, session_id: "duplicated-session")
    beacon = Fabricate(:browser_pageview_event, session_id: "duplicated-session")
    standalone_beacon = Fabricate(:browser_pageview_event, session_id: "beacon-session")
    duplicated_score = BrowserPageviewEventScore.create!(event_id: duplicated_legacy.id)
    standalone_legacy_score = BrowserPageviewEventScore.create!(event_id: standalone_legacy.id)
    beacon_score = BrowserPageviewEventScore.create!(event_id: beacon.id)
    DB.exec(
      "UPDATE browser_pageview_events SET source = 1 WHERE id IN (:ids)",
      ids: [standalone_legacy.id, another_standalone_legacy.id, duplicated_legacy.id],
    )
    DB.exec(
      "ALTER TABLE browser_pageview_events ENABLE TRIGGER skip_piggyback_browser_pageview_events",
    )

    event_data =
      DB.query_single(
        "SELECT to_jsonb(events) FROM browser_pageview_events events WHERE id = :id",
        id: duplicated_legacy.id,
      )
    score_data =
      DB.query_single(
        "SELECT to_jsonb(scores) FROM browser_pageview_event_scores scores WHERE id = :id",
        id: duplicated_score.id,
      )

    stub_const(described_class, "BATCH_SIZE", 2) { described_class.new.up }
    described_class.new.up

    expect(
      DB.query_single("SELECT to_jsonb(events) FROM browser_pageview_events_backup events"),
    ).to eq(event_data)
    expect(
      DB.query_single("SELECT to_jsonb(scores) FROM browser_pageview_event_scores_backup scores"),
    ).to eq(score_data)

    expect(BrowserPageviewEvent.pluck(:id)).to contain_exactly(
      beacon.id,
      standalone_legacy.id,
      another_standalone_legacy.id,
      standalone_beacon.id,
    )
    expect(BrowserPageviewEvent.where(id: duplicated_legacy.id)).not_to exist
    expect(BrowserPageviewEventScore.pluck(:id)).to contain_exactly(
      standalone_legacy_score.id,
      beacon_score.id,
    )
    expect(BrowserPageviewEventScore.where(id: duplicated_score.id)).not_to exist
  end
end
