# frozen_string_literal: true

describe Chat::DuplicateMessageValidator do
  let(:message) { "goal!" }
  fab!(:category_channel) { Fabricate(:chat_channel) }
  fab!(:dm_channel) { Fabricate(:direct_message_channel) }
  fab!(:user) { Fabricate(:user) }

  def message_blocked?(message:, chat_channel:, user:)
    chat_message = Fabricate.build(:chat_message, user:, message:, chat_channel:)
    described_class.new(chat_message).validate
    chat_message.errors.full_messages.include?(I18n.t("chat.errors.duplicate_message"))
  end

  it "blocks a message if it was posted in a category channel in the last 30 seconds by the same user" do
    Fabricate(
      :chat_message,
      created_at: 1.second.ago,
      user:,
      message:,
      chat_channel: category_channel,
    )

    expect(message_blocked?(message:, user:, chat_channel: category_channel)).to eq(true)
  end

  it "doesn't block a message if it's different" do
    Fabricate(
      :chat_message,
      created_at: 1.second.ago,
      user:,
      message:,
      chat_channel: category_channel,
    )

    expect(message_blocked?(message: "BUT!", user:, chat_channel: category_channel)).to eq(false)
  end

  it "doesn't block a message if it was posted more than 30 seconds ago" do
    Fabricate(
      :chat_message,
      created_at: 31.seconds.ago,
      user:,
      message:,
      chat_channel: category_channel,
    )

    expect(message_blocked?(message:, user:, chat_channel: category_channel)).to eq(false)
  end

  it "blocks a message case insensitively" do
    Fabricate(
      :chat_message,
      created_at: 1.second.ago,
      user:,
      message:,
      chat_channel: category_channel,
    )

    expect(message_blocked?(message: message.upcase, user:, chat_channel: category_channel)).to eq(
      true,
    )
  end

  it "doesn't block a message if it was posted by a different user" do
    Fabricate(
      :chat_message,
      created_at: 1.second.ago,
      user: Fabricate(:user),
      message:,
      chat_channel: category_channel,
    )

    expect(message_blocked?(message:, user:, chat_channel: category_channel)).to eq(false)
  end

  it "doesn't block a message if it was posted in a different channel" do
    Fabricate(
      :chat_message,
      created_at: 1.second.ago,
      user:,
      message:,
      chat_channel: Fabricate(:chat_channel),
    )

    expect(message_blocked?(message:, user:, chat_channel: category_channel)).to eq(false)
  end

  it "doesn't block a message if it was posted by a bot" do
    bot = Fabricate(:bot)

    Fabricate(
      :chat_message,
      created_at: 1.second.ago,
      user: bot,
      message:,
      chat_channel: category_channel,
    )

    expect(message_blocked?(message:, user: bot, chat_channel: category_channel)).to eq(false)
  end

  it "doesn't block a message if it was posted in a 1:1 DM" do
    Fabricate(:chat_message, created_at: 1.second.ago, user:, message:, chat_channel: dm_channel)

    expect(message_blocked?(message:, user:, chat_channel: dm_channel)).to eq(false)
  end
end
