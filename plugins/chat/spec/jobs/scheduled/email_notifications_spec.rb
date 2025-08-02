# frozen_string_literal: true

describe Jobs::Chat::EmailNotifications do
  before { Jobs.run_immediately! }

  context "when chat is enabled" do
    before { SiteSetting.chat_enabled = true }

    it "starts the mailer" do
      Chat::Mailer.expects(:send_unread_mentions_summary)

      Jobs.enqueue(Jobs::Chat::EmailNotifications)
    end
  end

  context "when chat is not enabled" do
    before { SiteSetting.chat_enabled = false }

    it "does nothing" do
      Chat::Mailer.expects(:send_unread_mentions_summary).never

      Jobs.enqueue(Jobs::Chat::EmailNotifications)
    end
  end
end
