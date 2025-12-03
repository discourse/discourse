# frozen_string_literal: true

RSpec.describe Chat::MessageLink do
  fab!(:user)
  fab!(:channel, :chat_channel)

  describe ".extract_from" do
    it "extracts external links from a chat message" do
      message =
        Fabricate(
          :chat_message,
          chat_channel: channel,
          user: user,
          message: "Check out https://github.com/discourse/discourse/pull/123",
        )
      message.update!(cooked: PrettyText.cook(message.message))

      Chat::MessageLink.extract_from(message)

      expect(Chat::MessageLink.count).to eq(1)
      link = Chat::MessageLink.first
      expect(link.url).to eq("https://github.com/discourse/discourse/pull/123")
      expect(link.domain).to eq("github.com")
      expect(link.chat_message_id).to eq(message.id)
      expect(link.chat_channel_id).to eq(channel.id)
      expect(link.user_id).to eq(user.id)
    end

    it "extracts multiple links from a message" do
      message =
        Fabricate(
          :chat_message,
          chat_channel: channel,
          user: user,
          message: "PRs: https://github.com/org/repo/pull/1 and https://github.com/org/repo/pull/2",
        )
      message.update!(cooked: PrettyText.cook(message.message))

      Chat::MessageLink.extract_from(message)

      expect(Chat::MessageLink.count).to eq(2)
      urls = Chat::MessageLink.pluck(:url)
      expect(urls).to contain_exactly(
        "https://github.com/org/repo/pull/1",
        "https://github.com/org/repo/pull/2",
      )
    end

    it "removes links that no longer exist in the message" do
      message =
        Fabricate(
          :chat_message,
          chat_channel: channel,
          user: user,
          message: "Check out https://github.com/org/repo/pull/1",
        )
      message.update!(cooked: PrettyText.cook(message.message))
      Chat::MessageLink.extract_from(message)

      expect(Chat::MessageLink.count).to eq(1)

      message.update!(
        message: "Check out https://github.com/org/repo/pull/2",
        cooked: PrettyText.cook("Check out https://github.com/org/repo/pull/2"),
      )
      Chat::MessageLink.extract_from(message)

      expect(Chat::MessageLink.count).to eq(1)
      expect(Chat::MessageLink.first.url).to eq("https://github.com/org/repo/pull/2")
    end

    it "does not extract mailto links" do
      message =
        Fabricate(
          :chat_message,
          chat_channel: channel,
          user: user,
          message: "Email me at mailto:test@example.com",
        )
      message.update!(cooked: PrettyText.cook(message.message))

      Chat::MessageLink.extract_from(message)

      expect(Chat::MessageLink.count).to eq(0)
    end

    it "does nothing for deleted messages" do
      message =
        Fabricate(
          :chat_message,
          chat_channel: channel,
          user: user,
          message: "https://github.com/org/repo/pull/1",
          deleted_at: Time.current,
        )
      message.update!(cooked: PrettyText.cook(message.message))

      Chat::MessageLink.extract_from(message)

      expect(Chat::MessageLink.count).to eq(0)
    end

    it "is idempotent" do
      message =
        Fabricate(
          :chat_message,
          chat_channel: channel,
          user: user,
          message: "https://github.com/org/repo/pull/1",
        )
      message.update!(cooked: PrettyText.cook(message.message))

      3.times { Chat::MessageLink.extract_from(message) }

      expect(Chat::MessageLink.count).to eq(1)
    end
  end
end
