# frozen_string_literal: true

require Rails.root.join(
          "plugins/discourse-calendar/db/post_migrate/20260622201005_backfill_livestream_from_tag.rb",
        )

RSpec.describe BackfillLivestreamFromTag do
  subject(:migrate) { described_class.new.up }

  fab!(:livestream_tag) { Fabricate(:tag, name: "livestream") }
  fab!(:other_tag) { Fabricate(:tag, name: "webinar") }

  fab!(:tagged_topic) { Fabricate(:topic, tags: [livestream_tag]) }
  fab!(:tagged_event) { Fabricate(:event, post: Fabricate(:post, topic: tagged_topic)) }

  fab!(:untagged_topic) { Fabricate(:topic, tags: [other_tag]) }
  fab!(:untagged_event) { Fabricate(:event, post: Fabricate(:post, topic: untagged_topic)) }

  # A livestream-tagged topic whose event sits on a reply, not the first post.
  fab!(:reply_event_topic) { Fabricate(:topic, tags: [livestream_tag]) }
  fab!(:reply_event) do
    Fabricate(:post, topic: reply_event_topic) # first post, no event
    Fabricate(:event, post: Fabricate(:post, topic: reply_event_topic)) # event on a reply
  end

  before do
    @original_verbose = ActiveRecord::Migration.verbose
    ActiveRecord::Migration.verbose = false
  end

  after { ActiveRecord::Migration.verbose = @original_verbose }

  context "when livestream_enabled is true" do
    before do
      # livestream_enabled is no longer a registered setting; insert the row the
      # way an upgraded site carries it (see CopyLivestreamSettingsToCalendar).
      DB.exec(<<~SQL)
        INSERT INTO site_settings (name, data_type, value, created_at, updated_at)
        VALUES ('livestream_enabled', 5, 't', NOW(), NOW())
      SQL
    end

    it "enables livestream on events whose topic has the livestream tag" do
      migrate

      expect(tagged_event.reload.livestream).to eq(true)
    end

    it "leaves events whose topic lacks the livestream tag unchanged" do
      migrate

      expect(untagged_event.reload.livestream).to eq(false)
    end

    it "leaves events that are not on the first post unchanged" do
      migrate

      expect(reply_event.reload.livestream).to eq(false)
    end
  end

  it "does nothing when livestream_enabled is not set" do
    migrate

    expect(tagged_event.reload.livestream).to eq(false)
  end
end
