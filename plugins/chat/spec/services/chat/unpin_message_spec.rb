# frozen_string_literal: true

RSpec.describe Chat::UnpinMessage do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:message_id) }
    it { is_expected.to validate_presence_of(:channel_id) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:current_user, :admin)
    fab!(:channel, :chat_channel)
    fab!(:message) { Fabricate(:chat_message, chat_channel: channel) }
    fab!(:pin) { Fabricate(:chat_pinned_message, chat_message: message, chat_channel: channel) }

    let(:guardian) { Guardian.new(current_user) }
    let(:params) { { message_id: message.id, channel_id: channel.id } }
    let(:dependencies) { { guardian: } }

    context "when params are not valid" do
      let(:params) { {} }

      it { is_expected.to fail_a_contract }
    end

    context "when message is not found" do
      let(:params) { { message_id: -1, channel_id: channel.id } }

      it { is_expected.to fail_to_find_a_model(:message) }
    end

    context "when user cannot unpin" do
      fab!(:current_user, :user)

      it { is_expected.to fail_a_policy(:can_unpin) }
    end

    context "when message is not pinned" do
      before { pin.destroy! }

      it { is_expected.to fail_to_find_a_model(:pin) }
    end

    context "when all conditions are met" do
      it { is_expected.to run_successfully }

      it "destroys the pinned message record" do
        pin_id = pin.id
        expect { result }.to change { Chat::PinnedMessage.count }.by(-1)
        expect(Chat::PinnedMessage.find_by(id: pin_id)).to be_nil
      end

      it "does not post a system message" do
        expect { result }.not_to change { Chat::Message.where(user: Discourse.system_user).count }
      end

      it "publishes a MessageBus event" do
        messages = MessageBus.track_publish { result }
        unpin_event = messages.find { |m| m.data["type"] == "unpin" }

        expect(unpin_event).to be_present
        expect(unpin_event.channel).to eq("/chat/#{channel.id}")
        expect(unpin_event.data["chat_message_id"]).to eq(message.id)
      end
    end
  end
end
