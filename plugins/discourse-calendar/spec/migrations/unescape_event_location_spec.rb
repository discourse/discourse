# frozen_string_literal: true

require Rails.root.join(
          "plugins/discourse-calendar/db/migrate/20260723094850_unescape_event_location.rb",
        )

RSpec.describe UnescapeEventLocation do
  subject(:migrate) { described_class.new.up }

  before do
    @original_verbose = ActiveRecord::Migration.verbose
    ActiveRecord::Migration.verbose = false
  end

  after { ActiveRecord::Migration.verbose = @original_verbose }

  it "unescapes stored locations exactly two levels, matching re-derivation from raw" do
    escaped = Fabricate(:event, location: "Joe &amp; Sons (downtown)")
    escalated = Fabricate(:event, location: "Joe &amp;amp; Sons")
    plain = Fabricate(:event, location: "Tom & Jerry")
    no_entities = Fabricate(:event, location: "Conference Room A")
    no_location = Fabricate(:event)

    migrate

    expect(escaped.reload.location).to eq("Joe & Sons (downtown)")
    expect(escalated.reload.location).to eq("Joe & Sons")
    expect(plain.reload.location).to eq("Tom & Jerry")
    expect(no_entities.reload.location).to eq("Conference Room A")
    expect(no_location.reload.location).to be_nil
  end
end
