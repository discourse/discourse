# frozen_string_literal: true

RSpec.describe Chat::TrashMessages do
  fab!(:current_user) { Fabricate(:user) }
  let!(:guardian) { Guardian.new(current_user) }
  fab!(:chat_channel) { Fabricate(:chat_channel) }
  fab!(:message1) { Fabricate(:chat_message, user: current_user, chat_channel: chat_channel) }
  fab!(:message2) { Fabricate(:chat_message, user: current_user, chat_channel: chat_channel) }

  describe ".call" do
    subject(:result) do
      described_class.call(
        message_ids: [message1.id, message2.id],
        channel_id: chat_channel.id,
        guardian: guardian,
      )
    end

    context "when params are valid" do
      it "processes the messages successfully" do
        result
        expect(Chat::Message.find_by(id: message1.id)).to be_nil
        expect(Chat::Message.find_by(id: message2.id)).to be_nil
      end

      it "publishes a bulk delete event" do
        Chat::Publisher.expects(:publish_bulk_delete!).once
        result
      end

      it "does not publish events for single message deletes" do
        Chat::Publisher.expects(:publish_delete).never
        result
      end
    end

    context "when one of the messages does not exist" do
      before { message1.destroy! }

      it "still processes the other message successfully" do
        result
        expect(Chat::Message.find_by(id: message2.id)).to be_nil
      end
    end

    context "when an empty array of message_ids is provided" do
      subject(:result) do
        described_class.call(
          message_ids: [],
          channel_id: message1.chat_channel_id,
          guardian: guardian,
        )
      end

      it "fails due to validation" do
        expect(result).to fail_a_contract
      end
    end

    context "when message_ids exceed the limit" do
      subject(:result) do
        described_class.call(
          message_ids: (1..51).to_a,
          channel_id: message1.chat_channel_id,
          guardian: guardian,
        )
      end

      it "fails due to validation" do
        expect(result).to fail_a_contract
      end
    end
  end
end
