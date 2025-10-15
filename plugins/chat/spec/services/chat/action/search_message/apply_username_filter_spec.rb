# frozen_string_literal: true

RSpec.describe Chat::Action::SearchMessage::ApplyUsernameFilter do
  subject(:result) { described_class.call(messages:, username:, guardian:) }

  fab!(:current_user, :user)
  fab!(:channel, :chat_channel)
  fab!(:alice) { Fabricate(:user, username: "alice") }
  fab!(:bob) { Fabricate(:user, username: "bob") }

  let(:guardian) { Guardian.new(current_user) }
  let(:messages) { Chat::Message.where(chat_channel: channel) }

  before do
    channel.add(current_user)
    SiteSetting.chat_enabled = true
  end

  context "with existing username" do
    fab!(:alice_message_1) do
      Fabricate(:chat_message, chat_channel: channel, user: alice, message: "first message")
    end
    fab!(:alice_message_2) do
      Fabricate(:chat_message, chat_channel: channel, user: alice, message: "second message")
    end
    fab!(:bob_message) do
      Fabricate(:chat_message, chat_channel: channel, user: bob, message: "bob's message")
    end

    let(:username) { "alice" }

    it "returns only messages from that user" do
      expect(result).to contain_exactly(alice_message_1, alice_message_2)
    end
  end

  context "with case insensitive username" do
    fab!(:alice_message) do
      Fabricate(:chat_message, chat_channel: channel, user: alice, message: "alice's message")
    end

    let(:username) { "ALICE" }

    it "filters messages correctly regardless of case" do
      expect(result).to contain_exactly(alice_message)
    end
  end

  context "with @me special case" do
    fab!(:current_user_message_1) do
      Fabricate(:chat_message, chat_channel: channel, user: current_user, message: "my first")
    end
    fab!(:current_user_message_2) do
      Fabricate(:chat_message, chat_channel: channel, user: current_user, message: "my second")
    end
    fab!(:alice_message) do
      Fabricate(:chat_message, chat_channel: channel, user: alice, message: "alice's message")
    end

    let(:username) { "me" }

    it "returns messages from the current user" do
      expect(result).to contain_exactly(current_user_message_1, current_user_message_2)
    end
  end

  context "with non-existent username" do
    fab!(:alice_message) do
      Fabricate(:chat_message, chat_channel: channel, user: alice, message: "alice's message")
    end

    let(:username) { "nonexistent" }

    it "returns no messages" do
      expect(result).to be_empty
    end
  end

  context "with staged user" do
    fab!(:staged_user) { Fabricate(:user, username: "staged", staged: true) }
    fab!(:staged_message) do
      Fabricate(:chat_message, chat_channel: channel, user: staged_user, message: "staged message")
    end
    fab!(:alice_message) do
      Fabricate(:chat_message, chat_channel: channel, user: alice, message: "alice's message")
    end

    let(:username) { "staged" }

    it "excludes messages from staged users" do
      expect(result).to be_empty
    end
  end

  context "when user is nil" do
    let(:guardian) { Guardian.new(nil) }
    let(:username) { "me" }

    fab!(:alice_message) do
      Fabricate(:chat_message, chat_channel: channel, user: alice, message: "alice's message")
    end

    it "returns no messages" do
      expect(result).to be_empty
    end
  end

  context "with username containing special characters" do
    fab!(:user_underscore) { Fabricate(:user, username: "user_underscore") }
    fab!(:message) do
      Fabricate(:chat_message, chat_channel: channel, user: user_underscore, message: "message")
    end

    let(:username) { "user_underscore" }

    it "normalizes and filters correctly" do
      expect(result).to contain_exactly(message)
    end
  end
end
