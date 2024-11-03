# frozen_string_literal: true

RSpec.describe Chat::StopReply do
  describe described_class::Contract, type: :model do
    subject(:contract) { described_class.new }

    it { is_expected.to validate_presence_of :channel_id }
    it { is_expected.to validate_presence_of :client_id }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:user)
    fab!(:channel) { Fabricate(:chat_channel, threading_enabled: true) }
    fab!(:thread) { Fabricate(:chat_thread, channel: channel) }
    fab!(:client_id) do
      Chat::StartReply.call(
        params: {
          channel_id: channel.id,
          thread_id: thread.id,
        },
        guardian: user.guardian,
      ).client_id
    end

    let(:guardian) { user.guardian }
    let(:params) { { client_id: client_id, channel_id: channel.id, thread_id: thread.id } }
    let(:dependencies) { { guardian: } }

    before { channel.add(guardian.user) }

    context "when the channel is not found" do
      before { params[:channel_id] = 999 }

      it { is_expected.to fail_to_find_a_model(:presence_channel) }
    end

    context "when the thread is not found" do
      before { params[:thread_id] = 999 }

      it { is_expected.to fail_to_find_a_model(:presence_channel) }
    end

    it "leaves the presence channel" do
      presence_channel = PresenceChannel.new("/chat-reply/#{channel.id}/thread/#{thread.id}")

      expect { result }.to change { presence_channel.count }.by(-1)
    end
  end
end
