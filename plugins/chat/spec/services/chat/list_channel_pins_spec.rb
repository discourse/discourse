# frozen_string_literal: true

RSpec.describe Chat::ListChannelPins do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:channel_id) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:chatters, :group)
    fab!(:user) { Fabricate(:user, group_ids: [chatters.id]) }
    fab!(:channel, :chat_channel)
    fab!(:membership) do
      Fabricate(:user_chat_channel_membership, chat_channel: channel, user: user)
    end
    fab!(:message_1) { Fabricate(:chat_message, chat_channel: channel) }
    fab!(:message_2) { Fabricate(:chat_message, chat_channel: channel) }
    fab!(:pin_1) { Fabricate(:chat_pinned_message, chat_channel: channel, chat_message: message_1) }
    fab!(:pin_2) { Fabricate(:chat_pinned_message, chat_channel: channel, chat_message: message_2) }

    let(:guardian) { Guardian.new(user) }
    let(:params) { { channel_id: channel.id } }
    let(:dependencies) { { guardian: } }

    before { SiteSetting.chat_allowed_groups = chatters }

    context "when params are not valid" do
      let(:params) { {} }

      it { is_expected.to fail_a_contract }
    end

    context "when channel is not found" do
      let(:params) { { channel_id: -1 } }

      it { is_expected.to fail_to_find_a_model(:channel) }
    end

    context "when user cannot access channel" do
      fab!(:private_category) { Fabricate(:private_category, group: Fabricate(:group)) }

      before { channel.update!(chatable: private_category) }

      it { is_expected.to fail_a_policy(:can_view_channel) }
    end

    context "when all conditions are met" do
      it { is_expected.to run_successfully }

      it "returns pinned messages" do
        expect(result[:pins]).to contain_exactly(pin_1, pin_2)
      end

      it "returns membership" do
        expect(result[:membership]).to eq(membership)
      end

      it "marks pins as read in database" do
        freeze_time
        expect { result }.to change { membership.reload.last_viewed_pins_at }.to(Time.zone.now)
      end

      it "restores old last_viewed_pins_at on returned membership for serialization" do
        membership.update!(last_viewed_pins_at: 1.day.ago)
        old_timestamp = membership.last_viewed_pins_at
        result
        expect(result[:membership].last_viewed_pins_at).to eq_time(old_timestamp)
      end

      context "when user has no membership" do
        before { membership.destroy! }

        it { is_expected.to run_successfully }

        it "returns pinned messages" do
          expect(result[:pins]).to contain_exactly(pin_1, pin_2)
        end

        it "returns nil membership" do
          expect(result[:membership]).to be_nil
        end
      end
    end
  end
end
