# frozen_string_literal: true

RSpec.describe Chat::StartReply do
  describe described_class::Contract, type: :model do
    subject(:contract) { described_class.new }

    it { is_expected.to validate_presence_of :channel_id }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:user)
    fab!(:channel) { Fabricate(:chat_channel, threading_enabled: true) }
    fab!(:thread) { Fabricate(:chat_thread, channel: channel) }

    let(:guardian) { user.guardian }
    let(:params) { { channel_id: channel.id, thread_id: thread.id } }
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

    it "generates a client id" do
      expect(result.client_id).to be_present
    end

    it "joins the presence channel" do
      expect { result }.to change {
        PresenceChannel.new("/chat-reply/#{channel.id}/thread/#{thread.id}").count
      }.by(1)
    end

    context "when the user is not part of the channel" do
      fab!(:channel) { Fabricate(:private_category_channel, threading_enabled: true) }

      before { params[:thread_id] = nil }

      it { is_expected.to fail_a_step(:join_chat_reply_presence_channel) }
    end
  end
end
