# frozen_string_literal: true

RSpec.describe Chat::ChannelSerializer do
  fab!(:category)
  fab!(:viewer, :user)
  let(:topic) { Fabricate(:topic, category:) }
  let(:first_post) { Fabricate(:post, topic:) }

  before do
    SiteSetting.calendar_enabled = true
    SiteSetting.discourse_post_event_enabled = true
    SiteSetting.chat_enabled = true
    # avoid the onebox-warming job making a real request
    Jobs.run_later!
    first_post
  end

  def create_event(livestream: true, status: :public, raw_invitees: nil)
    DiscoursePostEvent::Event.create!(
      id: first_post.id,
      original_starts_at: 1.hour.from_now,
      original_ends_at: 2.hours.from_now,
      location: "https://example.com/live",
      status: DiscoursePostEvent::Event.statuses[status],
      raw_invitees:,
      livestream:,
    )
  end

  def livestream_channel
    topic.reload.topic_chat_channel.chat_channel
  end

  def serialize(channel, user)
    described_class.new(channel, scope: Guardian.new(user), root: nil).as_json
  end

  describe "#livestream_topic" do
    it "references the linked topic for accessible livestream channels" do
      create_event(livestream: true)

      expect(serialize(livestream_channel, viewer)[:livestream_topic]).to include(
        id: topic.id,
        title: topic.title,
        slug: topic.slug,
        url: topic.relative_url,
        event_id: first_post.id,
      )
    end

    it "is omitted for channels without a linked livestream topic" do
      channel = Fabricate(:chat_channel, chatable: category)

      expect(serialize(channel, viewer)).not_to have_key(:livestream_topic)
    end

    it "is omitted for users who cannot access a private event" do
      create_event(livestream: true, status: :private, raw_invitees: ["some_group"])

      expect(serialize(livestream_channel, viewer)).not_to have_key(:livestream_topic)
    end

    it "is included for users in an invited group" do
      group = Fabricate(:group)
      group.add(viewer)
      create_event(livestream: true, status: :private, raw_invitees: [group.name])

      expect(serialize(livestream_channel, viewer)[:livestream_topic]).to include(id: topic.id)
    end

    it "is included for admins even when they cannot access the event" do
      create_event(livestream: true, status: :private, raw_invitees: ["some_group"])

      expect(serialize(livestream_channel, Fabricate(:admin))[:livestream_topic]).to include(
        id: topic.id,
      )
    end

    it "is omitted once livestream is disabled, even if the channel row remains" do
      event = create_event(livestream: true)
      channel = livestream_channel
      event.update!(livestream: false)

      expect(serialize(channel.reload, viewer)).not_to have_key(:livestream_topic)
    end
  end
end
