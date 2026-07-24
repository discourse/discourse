# frozen_string_literal: true

RSpec.describe DiscourseCalendar::Livestream do
  describe ".handle_topic_chat_channel_creation" do
    let(:topic) { Fabricate(:topic) }

    context "when the topic has no category" do
      it "does not create a chat channel" do
        described_class.handle_topic_chat_channel_creation(topic)

        expect(Chat::Channel.count).to eq(0)
      end
    end

    context "when the topic has a category" do
      let(:category) { Fabricate(:category) }

      before { topic.update!(category: category) }

      context "when the first post is not a livestream event" do
        before do
          SiteSetting.calendar_enabled = true
          post = Fabricate(:post, topic: topic)
          Fabricate(:event, post: post, livestream: false)
        end

        it "does not create a chat channel" do
          described_class.handle_topic_chat_channel_creation(topic)

          expect(Chat::Channel.count).to eq(0)
        end
      end

      context "when the first post is a livestream event" do
        before do
          SiteSetting.calendar_enabled = true
          SiteSetting.chat_pinned_messages = true
          post = Fabricate(:post, topic: topic)
          Fabricate(:event, post: post, livestream: true, location: "https://example.com/live")
        end

        it "creates a chat channel" do
          described_class.handle_topic_chat_channel_creation(topic)

          expect(Chat::Channel.count).to eq(1)
          expect(Chat::Channel.first.chatable).to eq(category)
          expect(Chat::Channel.first.emoji).to eq("spiral_calendar")
        end

        it "creates a topic chat channel" do
          described_class.handle_topic_chat_channel_creation(topic)

          expect(DiscourseCalendar::Livestream::TopicChatChannel.count).to eq(1)
          expect(DiscourseCalendar::Livestream::TopicChatChannel.first.topic).to eq(topic)
        end

        it "creates a user chat channel membership for the topic creator" do
          described_class.handle_topic_chat_channel_creation(topic)

          expect(Chat::UserChatChannelMembership.where(user: topic.user, following: false)).to exist
        end

        it "deletes the chat channel and the topic chat channel when the topic is destroyed" do
          described_class.handle_topic_chat_channel_creation(topic)

          expect(Chat::Channel.count).to eq(1)

          topic.destroy!

          expect(Chat::Channel.count).to eq(0)
          expect(DiscourseCalendar::Livestream::TopicChatChannel.count).to eq(0)
        end

        it "deletes the topic chat channel when the chat channel is destroyed" do
          described_class.handle_topic_chat_channel_creation(topic)

          expect(DiscourseCalendar::Livestream::TopicChatChannel.count).to eq(1)

          Chat::Channel.first.destroy!

          expect(DiscourseCalendar::Livestream::TopicChatChannel.count).to eq(0)
        end

        it "deletes the topic chat channel when the chat channel is soft deleted" do
          described_class.handle_topic_chat_channel_creation(topic)
          expect(DiscourseCalendar::Livestream::TopicChatChannel.count).to eq(1)
          expect(Chat::Channel.count).to eq(1)

          chat_channel = Chat::Channel.first
          Chat::TrashChannel.call(
            guardian: Guardian.new(Fabricate(:admin)),
            params: {
              channel_id: chat_channel.id,
            },
          )
          expect(chat_channel.reload).to be_trashed
          expect(DiscourseCalendar::Livestream::TopicChatChannel.count).to eq(0)
        end

        it "deletes the chat channel when topic chat channel is destroyed" do
          described_class.handle_topic_chat_channel_creation(topic)

          expect(DiscourseCalendar::Livestream::TopicChatChannel.count).to eq(1)

          DiscourseCalendar::Livestream::TopicChatChannel.first.destroy!

          expect(Chat::Channel.count).to eq(0)
        end

        it "posts a pinned message referencing the topic when pinned messages are enabled" do
          described_class.handle_topic_chat_channel_creation(topic)

          channel = Chat::Channel.first
          message = Chat::Message.find_by(chat_channel: channel, user: Discourse.system_user)
          expect(message.message).to include(topic.title)
          expect(message.message).to include(topic.relative_url)
          expect(Chat::PinnedMessage.where(chat_message: message, chat_channel: channel)).to exist
          expect(DiscourseCalendar::Livestream::TopicChatChannel.first.reference_message_id).to eq(
            message.id,
          )
        end

        it "escapes markdown metacharacters from the topic title in the reference message" do
          malicious =
            Fabricate(:topic, category: category, title: "Party](https://evil.example) oops")
          malicious_post = Fabricate(:post, topic: malicious)
          Fabricate(
            :event,
            post: malicious_post,
            livestream: true,
            location: "https://example.com/live",
          )

          channel = malicious.reload.topic_chat_channel.chat_channel
          message = Chat::Message.find_by(chat_channel: channel, user: Discourse.system_user)
          expect(message.message).to include("Party\\]\\(https://evil.example\\) oops")
          expect(message.message).not_to include("[Party](")
        end

        it "updated the chat channel when the topic category is updated" do
          described_class.handle_topic_chat_channel_creation(topic)

          expect(Chat::Channel.first.chatable).to eq(category)

          new_category = Fabricate(:category)

          topic.update!(category: new_category)

          expect(Chat::Channel.first.chatable).to eq(new_category)
        end
      end

      context "when the first post is a livestream event and pinned messages are disabled" do
        before do
          SiteSetting.calendar_enabled = true
          SiteSetting.chat_pinned_messages = false
          post = Fabricate(:post, topic: topic)
          Fabricate(:event, post: post, livestream: true, location: "https://example.com/live")
        end

        it "posts the topic reference message without pinning it" do
          described_class.handle_topic_chat_channel_creation(topic)

          channel = Chat::Channel.first
          expect(Chat::Message.where(chat_channel: channel, user: Discourse.system_user)).to exist
          expect(Chat::PinnedMessage.count).to eq(0)
        end
      end
    end
  end
end
