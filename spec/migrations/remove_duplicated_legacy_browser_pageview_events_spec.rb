# frozen_string_literal: true

require Rails.root.join(
          "db/post_migrate/20260831011842_remove_duplicated_legacy_browser_pageview_events.rb",
        )

RSpec.describe RemoveDuplicatedLegacyBrowserPageviewEvents do
  before do
    @original_verbose = ActiveRecord::Migration.verbose
    ActiveRecord::Migration.verbose = false
    ActiveRecord::Base.connection.add_column(
      :browser_pageview_events,
      :source,
      :integer,
      limit: 2,
      default: 1,
      null: false,
    )
  end

  after do
    ActiveRecord::Base.connection.remove_column(:browser_pageview_events, :source)
    ActiveRecord::Migration.verbose = @original_verbose
  end

  it "removes duplicated legacy events after batches without matches" do
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
      "UPDATE browser_pageview_events SET source = 2 WHERE id IN (:ids)",
      ids: [beacon.id, standalone_beacon.id],
    )

    stub_const(described_class, "BATCH_SIZE", 2) { described_class.new.up }

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
