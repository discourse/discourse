# frozen_string_literal: true

require Rails.root.join(
          "plugins/chat/db/migrate/20221201024458_make_channel_slugs_unique_with_index.rb",
        )

RSpec.describe MakeChannelSlugsUniqueWithIndex do
  fab!(:channel1) { Fabricate(:chat_channel, slug: "foo", created_at: 1.week.ago) }
  fab!(:channel2) { Fabricate(:chat_channel, slug: "bar") }
  fab!(:channel3) { Fabricate(:chat_channel, slug: "baz", created_at: 1.year.ago) }
  fab!(:channel4) { Fabricate(:chat_channel, slug: "foo-blah", created_at: 1.day.ago) }
  fab!(:channel5) { Fabricate(:chat_channel, slug: "foo-bling", created_at: 3.days.ago) }
  fab!(:channel6) { Fabricate(:chat_channel, slug: "baz-boo", created_at: 10.minutes.ago) }

  before { DB.exec("DROP INDEX index_chat_channels_on_slug") }

  after { DB.exec("CREATE UNIQUE INDEX index_chat_channels_on_slug ON chat_channels(slug)") }

  it "only changes conflicting slugs for channels created later than the first one" do
    # update to conflicting directly in SQL since ActiveRecord will not allow this
    DB.exec("UPDATE chat_channels SET slug = 'baz' WHERE id = #{channel6.id}")
    DB.exec("UPDATE chat_channels SET slug = 'foo' WHERE id = #{channel4.id}")
    DB.exec("UPDATE chat_channels SET slug = 'foo' WHERE id = #{channel5.id}")

    MakeChannelSlugsUniqueWithIndex.new.up

    [channel1, channel2, channel3, channel4, channel5, channel6].each(&:reload)

    expect(channel3.slug).to eq("baz")
    expect(channel6.slug).to eq("baz-#{channel6.id}")

    expect(channel1.slug).to eq("foo")
    expect(channel4.slug).to eq("foo-#{channel4.id}")
    expect(channel5.slug).to eq("foo-#{channel5.id}")

    expect(channel2.slug).to eq("bar")
  end
end
