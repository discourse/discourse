# frozen_string_literal: true

describe Jobs::Chat::ProcessMessage do
  fab!(:chat_message) { Fabricate(:chat_message, message: "https://discourse.org/team") }

  before do
    stub_request(:get, "https://discourse.org/team").to_return(
      status: 200,
      body: "<html><head><title>a</title></head></html>",
    )

    stub_request(:head, "https://discourse.org/team").to_return(status: 200)
  end

  it "updates cooked with oneboxes" do
    described_class.new.execute(chat_message_id: chat_message.id)
    expect(chat_message.reload.cooked).to eq(
      "<aside class=\"onebox allowlistedgeneric\" data-onebox-src=\"https://discourse.org/team\">\n  <header class=\"source\">\n\n      <a href=\"https://discourse.org/team\" target=\"_blank\" rel=\"nofollow ugc noopener\">discourse.org</a>\n  </header>\n\n  <article class=\"onebox-body\">\n    \n\n<h3><a href=\"https://discourse.org/team\" target=\"_blank\" rel=\"nofollow ugc noopener\">a</a></h3>\n\n\n\n  </article>\n\n  <div class=\"onebox-metadata\">\n    \n    \n  </div>\n\n  <div style=\"clear: both\"></div>\n</aside>\n",
    )
  end

  context "when the cooked message changed" do
    it "publishes the update" do
      chat_message.update!(cooked: "another lovely cat")
      Chat::Publisher.expects(:publish_processed!).once
      described_class.new.execute(chat_message_id: chat_message.id)
    end
  end

  it "does not error when message is deleted" do
    chat_message.destroy
    expect { described_class.new.execute(chat_message_id: chat_message.id) }.not_to raise_exception
  end

  it "extracts links from the message" do
    described_class.new.execute(chat_message_id: chat_message.id)

    link = Chat::MessageLink.find_by(chat_message_id: chat_message.id)
    expect(link).to be_present
    expect(link.url).to eq("https://discourse.org/team")
  end

  describe "invalidate_oneboxes" do
    it "invalidates cached oneboxes and fetches fresh content" do
      # Process the message once to populate the onebox cache
      described_class.new.execute(chat_message_id: chat_message.id)
      original_cooked = chat_message.reload.cooked
      expect(original_cooked).to include("discourse.org")

      # Update the stub to return different content
      stub_request(:get, "https://discourse.org/team").to_return(
        status: 200,
        body: "<html><head><title>Updated Title</title></head></html>",
      )

      # Rebake with invalidate_oneboxes: true - this should fetch fresh content
      described_class.new.execute(chat_message_id: chat_message.id, invalidate_oneboxes: true)
      new_cooked = chat_message.reload.cooked
      expect(new_cooked).to include("Updated Title")
    end
  end

  describe "skip_notifications" do
    fab!(:user)
    fab!(:mentioned_user, :user)
    fab!(:chat_channel)
    fab!(:message_with_mention) do
      Fabricate(:chat_message, chat_channel:, user:, message: "Hey @#{mentioned_user.username}!")
    end

    before do
      chat_channel.add(user)
      chat_channel.add(mentioned_user)
    end

    it "sends notifications by default" do
      expect_enqueued_with(job: Jobs::Chat::NotifyMentioned) do
        described_class.new.execute(chat_message_id: message_with_mention.id)
      end
    end

    it "skips notifications when skip_notifications is true" do
      expect_not_enqueued_with(job: Jobs::Chat::NotifyMentioned) do
        described_class.new.execute(
          chat_message_id: message_with_mention.id,
          skip_notifications: true,
        )
      end
    end

    it "skips watching notifications when skip_notifications is true" do
      expect_not_enqueued_with(job: Jobs::Chat::NotifyWatching) do
        described_class.new.execute(
          chat_message_id: message_with_mention.id,
          skip_notifications: true,
        )
      end
    end
  end
end
