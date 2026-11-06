# frozen_string_literal: true

RSpec.describe "Private message topic tracking state MessageBus audiences" do
  subject(:message_types) do
    sign_in(viewer)
    post "/message-bus/#{SecureRandom.hex}/poll?dlp=t", params: { channel => 0 }
    response
      .parsed_body
      .select { it["channel"] == channel && it.dig("data", "topic_id") == topic.id }
      .map { it.dig("data", "message_type") }
  end

  fab!(:author, :admin)
  fab!(:recipient, :user)
  fab!(:moderator)
  fab!(:removed_user, :user)

  let(:topic) { Fabricate(:private_message_topic, user: author, recipient:) }
  let(:channel) { PrivateMessageTopicTrackingState.user_channel(viewer.id) }
  let(:whisper) { false }
  let(:whispers_allowed_groups) { Group::AUTO_GROUPS[:staff].to_s }

  before do
    SiteSetting.whispers_allowed_groups = whispers_allowed_groups
    Fabricate(:post, topic:, user: author)
    [moderator, removed_user].each { topic.topic_allowed_users.create!(user: it) }

    [recipient, moderator, removed_user].each do
      TopicUser.change(
        it.id,
        topic.id,
        notification_level: NotificationLevels.all[:watching],
        last_read_post_number: 1,
      )
    end
    topic.remove_allowed_user(author, removed_user.username)

    sign_in(author)
    Jobs.with_immediate_jobs do
      post "/posts.json", params: { topic_id: topic.id, raw: "A reply to the message", whisper: }
    end
  end

  context "when the viewer is a recipient" do
    let(:viewer) { recipient }

    it "sends the unread state" do
      expect(message_types).to include("unread")
    end
  end

  context "when the viewer was removed from the message" do
    let(:viewer) { removed_user }

    it "hides the unread state" do
      expect(message_types).not_to include("unread")
    end
  end

  context "when the reply is a whisper" do
    let(:whisper) { true }
    let(:viewer) { moderator }

    context "when the viewer is a moderator who can see whispers" do
      it "sends the unread state" do
        expect(message_types).to include("unread")
      end
    end

    context "when the viewer is a moderator outside the whisper groups" do
      let(:whispers_allowed_groups) { Fabricate(:group).id.to_s }

      it "hides the unread state" do
        expect(message_types).not_to include("unread")
      end
    end
  end
end
