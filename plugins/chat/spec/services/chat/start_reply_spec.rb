# frozen_string_literal: true

RSpec.describe Chat::StartReply do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of :channel_id }

    describe "#channel_name" do
      subject(:contract) { described_class.new(channel_id: 1, thread_id:) }

      context "when thread_id is not present" do
        let(:thread_id) { nil }

        it "returns only the channel name" do
          expect(contract.channel_name).to eq("/chat-reply/1")
        end
      end

      context "when thread_id is present" do
        let(:thread_id) { 2 }

        it "returns the channel name with thread_id" do
          expect(contract.channel_name).to eq("/chat-reply/1/thread/2")
        end
      end
    end
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

    context "when data is invalid" do
      let(:params) { { channel_id: nil } }

      it { is_expected.to fail_a_contract }
    end

    context "when the channel is not found" do
      before { params[:channel_id] = 999 }

      it { is_expected.to fail_to_find_a_model(:presence_channel) }
    end

    context "when the thread is not found" do
      before { params[:thread_id] = 999 }

      it { is_expected.to fail_to_find_a_model(:presence_channel) }
    end

    context "when the user is not part of the channel" do
      fab!(:channel) { Fabricate(:private_category_channel, threading_enabled: true) }

      before { params[:thread_id] = nil }

      it { is_expected.to fail_with_exception(PresenceChannel::InvalidAccess) }
    end

    context "when everything’s ok" do
      it { is_expected.to run_successfully }

      it "generates a client id" do
        expect(result.client_id).to be_present
      end

      it "joins the presence channel" do
        expect { result }.to change {
          PresenceChannel.new("/chat-reply/#{channel.id}/thread/#{thread.id}").count
        }.by(1)
      end
    end
  end
end
