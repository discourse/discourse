# frozen_string_literal: true

RSpec.describe Jobs::ChatSendMessageNotifications do
  describe "#execute" do
    context "when the message doesn't exist" do
      it "does nothing" do
        Chat::Notifier.any_instance.expects(:notify_new).never
        Chat::Notifier.any_instance.expects(:notify_edit).never

        subject.execute(eason: "new", timestamp: 1.minute.ago)
      end
    end

    context "when there's a message" do
      fab!(:chat_message) { Fabricate(:chat_message) }

      it "does nothing when the reason is invalid" do
        Chat::Notifier.expects(:notify_new).never
        Chat::Notifier.expects(:notify_edit).never

        subject.execute(
          chat_message_id: chat_message.id,
          reason: "invalid",
          timestamp: 1.minute.ago,
        )
      end

      it "does nothing if there is no timestamp" do
        Chat::Notifier.any_instance.expects(:notify_new).never
        Chat::Notifier.any_instance.expects(:notify_edit).never

        subject.execute(chat_message_id: chat_message.id, reason: "new")
      end

      it "calls notify_new when the reason is 'new'" do
        Chat::Notifier.any_instance.expects(:notify_new).once
        Chat::Notifier.any_instance.expects(:notify_edit).never

        subject.execute(chat_message_id: chat_message.id, reason: "new", timestamp: 1.minute.ago)
      end

      it "calls notify_edit when the reason is 'edit'" do
        Chat::Notifier.any_instance.expects(:notify_new).never
        Chat::Notifier.any_instance.expects(:notify_edit).once

        subject.execute(chat_message_id: chat_message.id, reason: "edit", timestamp: 1.minute.ago)
      end
    end
  end
end
