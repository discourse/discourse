# frozen_string_literal: true

RSpec.describe Chat::Action::SearchMessage::ApplyChannelFilter do
  subject(:result) { described_class.call(messages: messages, match: match, guardian: guardian) }

  fab!(:current_user, :user)
  fab!(:channel_1) { Fabricate(:chat_channel, slug: "general") }
  fab!(:channel_2) { Fabricate(:chat_channel, slug: "random") }

  let(:guardian) { Guardian.new(current_user) }
  let(:messages) { Chat::Message.joins(:chat_channel) }
  let(:match) { channel_1.slug }

  before do
    channel_1.add(current_user)
    channel_2.add(current_user)
    SiteSetting.chat_enabled = true
  end

  context "with valid channel slug" do
    fab!(:message_1) do
      Fabricate(:chat_message, chat_channel: channel_1, message: "message in channel 1")
    end
    fab!(:message_2) do
      Fabricate(:chat_message, chat_channel: channel_1, message: "another in channel 1")
    end
    fab!(:message_3) do
      Fabricate(:chat_message, chat_channel: channel_2, message: "message in channel 2")
    end

    it "returns only messages from that channel" do
      expect(result).to contain_exactly(message_1, message_2)
    end
  end

  context "with case insensitive channel slug" do
    fab!(:message) { Fabricate(:chat_message, chat_channel: channel_1, message: "message") }

    let(:match) { channel_1.slug.upcase }

    it "filters messages correctly regardless of case" do
      expect(result).to contain_exactly(message)
    end
  end

  context "with non-existent channel slug" do
    fab!(:message) { Fabricate(:chat_message, chat_channel: channel_1, message: "message") }

    let(:match) { "nonexistent" }

    it "returns no messages" do
      expect(result).to be_empty
    end
  end

  context "when user cannot view the channel" do
    fab!(:private_channel, :private_category_channel)
    fab!(:private_message) do
      Fabricate(:chat_message, chat_channel: private_channel, message: "private message")
    end
    fab!(:public_message) do
      Fabricate(:chat_message, chat_channel: channel_1, message: "public message")
    end

    let(:match) { private_channel.slug }

    it "returns no messages" do
      expect(result).to be_empty
    end
  end

  context "with multiple channels accessible to user" do
    fab!(:channel_3) { Fabricate(:chat_channel, slug: "off-topic") }
    fab!(:message_1) { Fabricate(:chat_message, chat_channel: channel_1, message: "message 1") }
    fab!(:message_2) { Fabricate(:chat_message, chat_channel: channel_2, message: "message 2") }
    fab!(:message_3) { Fabricate(:chat_message, chat_channel: channel_3, message: "message 3") }

    before { channel_3.add(current_user) }

    let(:match) { channel_2.slug }

    it "filters to only the specified channel" do
      expect(result).to contain_exactly(message_2)
    end
  end

  context "when guardian has no user and channel is not public" do
    let(:guardian) { Guardian.new(nil) }

    fab!(:private_channel, :private_category_channel)
    fab!(:message) { Fabricate(:chat_message, chat_channel: private_channel, message: "message") }

    let(:match) { private_channel.slug }

    it "returns no messages" do
      expect(result).to be_empty
    end
  end

  context "with channel slug containing special characters" do
    fab!(:channel_special) { Fabricate(:chat_channel, slug: "my-special-channel") }
    fab!(:message) { Fabricate(:chat_message, chat_channel: channel_special, message: "message") }

    before { channel_special.add(current_user) }

    let(:match) { "my-special-channel" }

    it "filters correctly with special characters" do
      expect(result).to contain_exactly(message)
    end
  end
end
