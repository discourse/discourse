# frozen_string_literal: true

RSpec.describe Chat::PinMessage do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:message_id) }
    it { is_expected.to validate_presence_of(:channel_id) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:current_user, :admin)
    fab!(:channel, :chat_channel)
    fab!(:message) { Fabricate(:chat_message, chat_channel: channel) }

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

    context "when user cannot pin" do
      fab!(:current_user, :user)

      it { is_expected.to fail_a_policy(:can_pin) }
    end

    context "when pin limit is reached" do
      before do
        Chat::PinnedMessage::MAX_PINS_PER_CHANNEL.times do
          Fabricate(:chat_pinned_message, chat_channel: channel)
        end
      end

      it { is_expected.to fail_a_policy(:within_pin_limit) }
    end

    context "when message is already pinned" do
      before { Fabricate(:chat_pinned_message, chat_message: message, chat_channel: channel) }

      it { is_expected.to fail_a_policy(:not_already_pinned) }
    end

    context "when all conditions are met" do
      it { is_expected.to run_successfully }

      it "creates a pinned message record" do
        expect { result }.to change { Chat::PinnedMessage.count }.by(1)

        pin = Chat::PinnedMessage.last
        expect(pin.chat_message_id).to eq(message.id)
        expect(pin.chat_channel_id).to eq(channel.id)
        expect(pin.pinned_by_id).to eq(current_user.id)
      end

      it "does not post a system message" do
        expect { result }.not_to change { Chat::Message.where(user: Discourse.system_user).count }
      end

      it "publishes a MessageBus event" do
        messages = MessageBus.track_publish { result }
        pin_event = messages.find { |m| m.data["type"] == "pin" }

        expect(pin_event).to be_present
        expect(pin_event.channel).to eq("/chat/#{channel.id}")
        expect(pin_event.data["chat_message_id"]).to eq(message.id)
      end
    end
  end
end
