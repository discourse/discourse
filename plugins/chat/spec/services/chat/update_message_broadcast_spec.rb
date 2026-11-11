# frozen_string_literal: true

RSpec.describe Chat::UpdateMessageBroadcast do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:message_id) }
    it { is_expected.to validate_presence_of(:channel_id) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:author, :user)
    fab!(:channel) do
      Fabricate(:category_channel, threading_enabled: true, broadcast_replies_enabled: true)
    end
    fab!(:thread) { Fabricate(:chat_thread, channel:) }
    fab!(:reply) { Fabricate(:chat_message, chat_channel: channel, user: author, thread:) }

    let(:current_user) { author }
    let(:guardian) { current_user.guardian }
    let(:dependencies) { { guardian: } }
    let(:params) { { message_id: reply.id, channel_id: channel.id, broadcast: true } }

    before { channel.add(author) }

    context "when params are not valid" do
      let(:params) { {} }

      it { is_expected.to fail_a_contract }
    end

    context "when the message is not in the channel" do
      let(:params) { { message_id: -1, channel_id: channel.id, broadcast: true } }

      it { is_expected.to fail_to_find_a_model(:message) }
    end

    context "when the user is not the author and has no moderation rights" do
      fab!(:other_user, :user)
      let(:current_user) { other_user }

      it { is_expected.to fail_a_policy(:can_manage_broadcast) }
    end

    context "when the user is an admin and not the author" do
      fab!(:admin, :admin)
      let(:current_user) { admin }

      it { is_expected.to run_successfully }
    end

    context "when the channel is read-only" do
      before { channel.update!(status: :read_only) }

      it { is_expected.to fail_a_policy(:channel_allows_message_creation) }
    end

    context "when the channel is a direct message channel" do
      fab!(:dm_channel) { Fabricate(:direct_message_channel, users: [author]) }
      fab!(:dm_thread) { Fabricate(:chat_thread, channel: dm_channel) }
      fab!(:dm_reply) do
        Fabricate(:chat_message, chat_channel: dm_channel, user: author, thread: dm_thread)
      end
      let(:params) { { message_id: dm_reply.id, channel_id: dm_channel.id, broadcast: true } }

      before do
        SiteSetting.chat_enabled = true
        SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:everyone]
        author.user_option.update!(allow_private_messages: true)
        dm_channel.add(author)
        dm_channel.update!(threading_enabled: true, broadcast_replies_enabled: true)
      end

      it "broadcasts the reply into the dm channel stream" do
        expect { result }.to change { dm_reply.reload.broadcasted }.to(true)
      end
    end

    context "when the channel option is disabled" do
      before { channel.update!(broadcast_replies_enabled: false) }

      it { is_expected.to fail_a_policy(:broadcastable_message) }
    end

    context "when the message is a thread original message" do
      before { thread.original_message.update!(user: author) }

      let(:params) do
        { message_id: thread.original_message_id, channel_id: channel.id, broadcast: true }
      end

      it { is_expected.to fail_a_policy(:broadcastable_message) }
    end

    context "when broadcasting a thread reply" do
      it "flags the message as broadcasted" do
        expect { result }.to change { reply.reload.broadcasted }.to(true)
      end

      it "shows the message in the channel message stream" do
        result
        messages = Chat::MessagesQuery.call(channel:, guardian:)[:messages]
        expect(messages).to include(reply)
      end

      it "promotes the message to the channel last message when it is newer" do
        expect { result }.to change { channel.reload.last_message_id }.to(reply.id)
      end

      it "publishes the message to the channel bus and refreshes the thread bus copy" do
        publishes = MessageBus.track_publish { result }

        channel_publish = publishes.find { |p| p.channel == "/chat/#{channel.id}" }
        thread_publish =
          publishes.find { |p| p.channel == "/chat/#{channel.id}/thread/#{thread.id}" }
        indicator_publish = publishes.find { |p| p.channel == "/chat/#{channel.id}/new-messages" }

        expect(channel_publish.data["type"]).to eq("sent")
        expect(thread_publish.data["type"]).to eq("edit")
        expect(indicator_publish.data[:type]).to eq("channel")
      end
    end

    context "when removing the broadcast" do
      let(:params) { { message_id: reply.id, channel_id: channel.id, broadcast: false } }

      before do
        reply.update!(broadcasted: true)
        channel.update!(last_message: reply)
      end

      it "clears the flag" do
        expect { result }.to change { reply.reload.broadcasted }.to(false)
      end

      it "recomputes the channel last message" do
        expect { result }.to change { channel.reload.last_message_id }.to(
          thread.original_message_id,
        )
      end

      it "publishes a delete to the channel bus and refreshes the thread bus copy" do
        publishes = MessageBus.track_publish { result }

        channel_publish = publishes.find { |p| p.channel == "/chat/#{channel.id}" }
        thread_publish =
          publishes.find { |p| p.channel == "/chat/#{channel.id}/thread/#{thread.id}" }

        expect(channel_publish.data["type"]).to eq("delete")
        expect(channel_publish.data["broadcast_removed"]).to be(true)
        expect(thread_publish.data["type"]).to eq("edit")
      end

      it "still succeeds when the channel option was turned off after broadcasting" do
        channel.update!(broadcast_replies_enabled: false)

        expect(result).to be_success
        expect(reply.reload.broadcasted).to eq(false)
      end

      it "still succeeds when the channel threading was turned off after broadcasting" do
        channel.update!(threading_enabled: false)

        expect(result).to be_success
        expect(reply.reload.broadcasted).to eq(false)
      end
    end
  end
end
