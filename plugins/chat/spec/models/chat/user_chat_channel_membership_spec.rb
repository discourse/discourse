# frozen_string_literal: true

RSpec.describe Chat::UserChatChannelMembership do
  describe "muted_until" do
    fab!(:membership, :user_chat_channel_membership)

    it "can be set to a future time" do
      membership.update!(muted: true, muted_until: 1.hour.from_now)

      expect(membership.reload.muted_until).to be_present
    end

    it "can't be set to a past time" do
      membership.muted = true
      membership.muted_until = 1.minute.ago

      expect(membership).not_to be_valid
      expect(membership.errors[:muted_until]).to be_present
    end

    it "is cleared when the channel is unmuted" do
      membership.update!(muted: true, muted_until: 1.hour.from_now)
      membership.update!(muted: false)

      expect(membership.reload.muted_until).to be_nil
    end
  end

  describe "#has_unseen_pins?" do
    fab!(:channel, :chat_channel)
    fab!(:user)
    fab!(:membership) do
      Fabricate(:user_chat_channel_membership, chat_channel: channel, user: user)
    end

    context "when channel has no pins" do
      it "returns false" do
        expect(membership.has_unseen_pins?).to eq(false)
      end
    end

    context "when user has never viewed pins" do
      fab!(:message) { Fabricate(:chat_message, chat_channel: channel) }
      fab!(:pin) { Fabricate(:chat_pinned_message, chat_channel: channel, chat_message: message) }

      it "returns true" do
        expect(membership.has_unseen_pins?).to eq(true)
      end
    end

    context "when user viewed pins before new pin was added" do
      fab!(:message) { Fabricate(:chat_message, chat_channel: channel) }

      before do
        membership.update!(last_viewed_pins_at: 1.hour.ago)
        Fabricate(:chat_pinned_message, chat_channel: channel, chat_message: message)
      end

      it "returns true" do
        expect(membership.has_unseen_pins?).to eq(true)
      end
    end

    context "when the only unseen pin was created by the user" do
      fab!(:message) { Fabricate(:chat_message, chat_channel: channel) }

      before do
        Fabricate(:chat_pinned_message, chat_channel: channel, chat_message: message, user: user)
      end

      it "returns false" do
        expect(membership.has_unseen_pins?).to eq(false)
      end
    end

    context "when user viewed pins after all pins were created" do
      fab!(:message) { Fabricate(:chat_message, chat_channel: channel, created_at: 2.hours.ago) }

      before do
        Fabricate(
          :chat_pinned_message,
          chat_channel: channel,
          chat_message: message,
          created_at: 2.hours.ago,
        )
        membership.update!(last_viewed_pins_at: 1.hour.ago)
      end

      it "returns false" do
        expect(membership.has_unseen_pins?).to eq(false)
      end
    end
  end
end
