# frozen_string_literal: true

describe ChatSDK::Channel do
  describe ".messages" do
    fab!(:channel_1) { Fabricate(:chat_channel) }
    fab!(:message_1) { Fabricate(:chat_message, chat_channel: channel_1) }
    fab!(:message_2) { Fabricate(:chat_message, chat_channel: channel_1) }

    let(:params) { { channel_id: channel_1.id, guardian: Discourse.system_user.guardian } }

    it "loads the messages" do
      messages = described_class.messages(**params)

      expect(messages).to eq([message_1, message_2])
    end

    it "accepts page_size" do
      messages = described_class.messages(**params, page_size: 1)

      expect(messages).to eq([message_1])
    end

    context "when guardian can't see the channel" do
      fab!(:channel_1) { Fabricate(:private_category_channel) }

      it "fails" do
        params[:guardian] = Fabricate(:user).guardian

        expect { described_class.messages(**params) }.to raise_error("Guardian can't view channel")
      end
    end

    context "when target_message doesn’t exist" do
      it "fails" do
        expect { described_class.messages(**params, target_message_id: -999) }.to raise_error(
          "Target message doesn't exist",
        )
      end
    end
  end

  describe ".start_reply" do
    fab!(:channel_1) { Fabricate(:chat_channel, threading_enabled: true) }
    fab!(:thread_1) { Fabricate(:chat_thread, channel: channel_1) }

    let(:params) do
      { channel_id: channel_1.id, thread_id: thread_1.id, guardian: Discourse.system_user.guardian }
    end

    it "starts a reply" do
      client_id = nil
      expect { client_id = described_class.start_reply(**params) }.to change {
        PresenceChannel.new("/chat-reply/#{channel_1.id}/thread/#{thread_1.id}").count
      }.by(1)

      expect(client_id).to be_present
    end

    context "when the channel doesn't exist" do
      it "fails" do
        params[:channel_id] = -999

        expect { described_class.start_reply(**params) }.to raise_error(
          "Chat::Channel or Chat::Thread not found.",
        )
      end
    end

    context "when the thread doesn't exist" do
      it "fails" do
        params[:thread_id] = -999

        expect { described_class.start_reply(**params) }.to raise_error(
          "Chat::Channel or Chat::Thread not found.",
        )
      end
    end
  end

  describe ".stop_reply" do
    fab!(:user) { Fabricate(:user) }
    fab!(:channel_1) { Fabricate(:chat_channel, threading_enabled: true) }
    fab!(:thread_1) { Fabricate(:chat_thread, channel: channel_1) }
    fab!(:client_id) do
      described_class.start_reply(
        channel_id: channel_1.id,
        thread_id: thread_1.id,
        guardian: user.guardian,
      )
    end

    let(:params) do
      {
        channel_id: channel_1.id,
        thread_id: thread_1.id,
        client_id: client_id,
        guardian: user.guardian,
      }
    end

    it "stops a reply" do
      expect { described_class.stop_reply(**params) }.to change {
        PresenceChannel.new("/chat-reply/#{channel_1.id}/thread/#{thread_1.id}").count
      }.by(-1)
    end

    context "when the channel doesn't exist" do
      it "fails" do
        params[:channel_id] = -999

        expect { described_class.stop_reply(**params) }.to raise_error(
          "Chat::Channel or Chat::Thread not found.",
        )
      end
    end

    context "when the thread doesn't exist" do
      it "fails" do
        params[:thread_id] = -999

        expect { described_class.stop_reply(**params) }.to raise_error(
          "Chat::Channel or Chat::Thread not found.",
        )
      end
    end
  end
end
