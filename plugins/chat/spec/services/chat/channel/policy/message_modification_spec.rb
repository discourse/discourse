# frozen_string_literal: true

RSpec.describe Chat::Channel::Policy::MessageModification do
  subject(:policy) { described_class.new(context) }

  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:chat_channel)
  fab!(:message) { Fabricate(:chat_message, chat_channel:, user:) }

  let(:guardian) { user.guardian }
  let(:context) { Service::Base::Context.build(message:, guardian:) }

  describe "#call" do
    subject(:result) { policy.call }

    context "when the channel is open" do
      it "returns true" do
        expect(result).to be_truthy
      end
    end

    context "when the channel is closed" do
      before { chat_channel.update!(status: :closed) }

      it "returns false" do
        expect(result).to be_falsey
      end
    end
  end

  describe "#reason" do
    subject(:reason) { policy.reason }

    context "when the channel is closed" do
      before { chat_channel.update!(status: "closed") }

      it "returns the closed message" do
        expect(reason).to eq(I18n.t("chat.errors.channel_modify_message_disallowed.closed"))
      end
    end

    context "when the channel is read_only" do
      before { chat_channel.update!(status: "read_only") }

      it "returns the read_only message" do
        expect(reason).to eq(I18n.t("chat.errors.channel_modify_message_disallowed.read_only"))
      end
    end

    context "when the channel is archived" do
      before { chat_channel.update!(status: "archived") }

      it "returns the archived message" do
        expect(reason).to eq(I18n.t("chat.errors.channel_modify_message_disallowed.archived"))
      end
    end
  end
end
