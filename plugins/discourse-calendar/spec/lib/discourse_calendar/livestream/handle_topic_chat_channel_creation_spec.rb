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
          post = Fabricate(:post, topic: topic)
          Fabricate(:event, post: post, livestream: true, location: "https://example.com/live")
        end

        it "creates a chat channel" do
          described_class.handle_topic_chat_channel_creation(topic)

          expect(Chat::Channel.count).to eq(1)
          expect(Chat::Channel.first.chatable).to eq(category)
        end

        it "creates a topic chat channel" do
          described_class.handle_topic_chat_channel_creation(topic)

          expect(DiscourseCalendar::Livestream::TopicChatChannel.count).to eq(1)
          expect(DiscourseCalendar::Livestream::TopicChatChannel.first.topic).to eq(topic)
        end

        it "creates a user chat channel membership" do
          described_class.handle_topic_chat_channel_creation(topic)

          expect(Chat::UserChatChannelMembership.count).to eq(1)
          expect(Chat::UserChatChannelMembership.first.user).to eq(topic.user)
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

        it "updated the chat channel when the topic category is updated" do
          described_class.handle_topic_chat_channel_creation(topic)

          expect(Chat::Channel.first.chatable).to eq(category)

          new_category = Fabricate(:category)

          topic.update!(category: new_category)

          expect(Chat::Channel.first.chatable).to eq(new_category)
        end
      end
    end
  end
end
