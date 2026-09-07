# frozen_string_literal: true

require Rails.root.join(
          "db/migrate/20260831011840_set_browser_pageview_event_source_default_to_beacon.rb",
        )

RSpec.describe SetBrowserPageviewEventSourceDefaultToBeacon do
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
