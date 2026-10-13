# frozen_string_literal: true

require Rails.root.join(
          "db/migrate/20260831011840_set_browser_pageview_event_source_default_to_beacon.rb",
        )

require Rails.root.join(
          "db/migrate/20260910030404_archive_duplicated_legacy_browser_pageview_events.rb",
        )

RSpec.describe SetBrowserPageviewEventSourceDefaultToBeacon do
  %w[default explicit].each do |beacon_source|
    it "preserves legacy events when a #{beacon_source} beacon arrives after archiving" do
      migration = described_class.new
      migration.suppress_messages { migration.down }

      legacy = Fabricate(:browser_pageview_event, session_id: "shared-session")
      another_legacy = Fabricate(:browser_pageview_event, session_id: legacy.session_id)
      unrelated_legacy = Fabricate(:browser_pageview_event)
      legacy_score = BrowserPageviewEventScore.create!(event_id: legacy.id)
      another_legacy_score = BrowserPageviewEventScore.create!(event_id: another_legacy.id)
      unrelated_score = BrowserPageviewEventScore.create!(event_id: unrelated_legacy.id)

      migration.suppress_messages do
        migration.up
        ArchiveDuplicatedLegacyBrowserPageviewEvents.new.up
      end
      expect(BrowserPageviewEvent.count).to eq(3)

      source_column = beacon_source == "explicit" ? ", source" : ""
      source_value = beacon_source == "explicit" ? ", 2" : ""
      beacon_ids = DB.query_single(<<~SQL, session_id: legacy.session_id)
        INSERT INTO browser_pageview_events
          (url, ip_address, user_agent, session_id, created_at#{source_column})
        VALUES
          ('/first', '1.2.3.4', 'test', :session_id, CURRENT_TIMESTAMP#{source_value}),
          ('/second', '1.2.3.4', 'test', :session_id, CURRENT_TIMESTAMP#{source_value})
        RETURNING id
      SQL

      expect(BrowserPageviewEvent.pluck(:id)).to contain_exactly(
        legacy.id,
        another_legacy.id,
        unrelated_legacy.id,
        *beacon_ids,
      )
      expect(BrowserPageviewEventScore.pluck(:id)).to contain_exactly(
        legacy_score.id,
        another_legacy_score.id,
        unrelated_score.id,
      )
    end
  end

  it "skips piggyback writes while allowing explicit and default beacon sources" do
    migration = described_class.new
    migration.suppress_messages do
      migration.down
      migration.up
    end
    beacon = Fabricate(:browser_pageview_event)

    DB.exec(<<~SQL, id: beacon.id)
      INSERT INTO browser_pageview_events
        (url, ip_address, user_agent, session_id, created_at, source)
      SELECT url, ip_address, user_agent, session_id, created_at, sources.source
      FROM browser_pageview_events
      CROSS JOIN (VALUES (1), (2)) AS sources(source)
      WHERE id = :id
    SQL

    expect(DB.query_single("SELECT source FROM browser_pageview_events")).to contain_exactly(2, 2)

    DB.exec("UPDATE browser_pageview_events SET source = 1 WHERE id = :id", id: beacon.id)

    expect(
      DB.query_single("SELECT source FROM browser_pageview_events WHERE id = :id", id: beacon.id),
    ).to eq([2])
  end
end
