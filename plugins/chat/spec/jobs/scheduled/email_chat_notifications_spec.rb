# frozen_string_literal: true

describe Jobs::EmailChatNotifications do
  before { Jobs.run_immediately! }

  context "when chat is enabled" do
    before { SiteSetting.chat_enabled = true }

    it "starts the mailer" do
      Chat::ChatMailer.expects(:send_unread_mentions_summary)

      Jobs.enqueue(:email_chat_notifications)
    end
  end

  context "when chat is not enabled" do
    before { SiteSetting.chat_enabled = false }

    it "does nothing" do
      Chat::ChatMailer.expects(:send_unread_mentions_summary).never

      Jobs.enqueue(:email_chat_notifications)
    end
  end
end
