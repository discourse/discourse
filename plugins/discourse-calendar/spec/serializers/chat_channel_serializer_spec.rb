# frozen_string_literal: true

RSpec.describe Chat::ChannelSerializer do
  fab!(:current_user, :user)
  fab!(:category)
  fab!(:topic) { Fabricate(:topic, category: category) }
  fab!(:first_post) { Fabricate(:post, topic: topic) }
  fab!(:channel) { Fabricate(:chat_channel, chatable: category) }

  before { SiteSetting.calendar_enabled = true }

  def serialize(channel)
    described_class.new(channel, scope: current_user.guardian, root: nil).as_json
  end

  describe "#livestream_topic" do
    it "references the linked topic for livestream topic channels" do
      topic_chat_channel =
        DiscourseCalendar::Livestream::TopicChatChannel.create!(
          topic: topic,
          chat_channel: channel,
          reference_message_id: 42,
        )

      expect(serialize(channel)[:livestream_topic]).to eq(
        id: topic.id,
        title: topic.title,
        slug: topic.slug,
        url: topic.relative_url,
        event_id: first_post.id,
        reference_message_id: topic_chat_channel.reference_message_id,
        can_update_attendance: false,
        watching_invitee_status: nil,
      )
    end

    it "is omitted for channels without a linked livestream topic" do
      expect(serialize(channel)).not_to have_key(:livestream_topic)
    end
  end
end
